# -------------------------------------------------------
# EKS Add-on: cert-manager (prerequisite for ADOT)
# -------------------------------------------------------
data "aws_eks_addon_version" "cert_manager_latest" {
  addon_name         = "cert-manager"
  kubernetes_version = module.eks_cluster.eks-cluster-version
  most_recent        = true
}

resource "aws_eks_addon" "cert_manager" {
  cluster_name                = module.eks_cluster.eks-cluster-id
  addon_name                  = "cert-manager"
  addon_version               = data.aws_eks_addon_version.cert_manager_latest.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

# -------------------------------------------------------
# EKS Add-on: ADOT
# -------------------------------------------------------
data "aws_eks_addon_version" "adot_latest" {
  addon_name         = "adot"
  kubernetes_version = module.eks_cluster.eks-cluster-version
  most_recent        = true
}

resource "aws_eks_addon" "adot" {
  depends_on                  = [aws_eks_addon.cert_manager]
  cluster_name                = module.eks_cluster.eks-cluster-id
  addon_name                  = "adot"
  addon_version               = data.aws_eks_addon_version.adot_latest.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  configuration_values = jsonencode({
    manager = {
      resources = {
        limits   = { cpu = "200m", memory = "256Mi" }
        requests = { cpu = "100m", memory = "64Mi" }
      }
    }
    replicaCount = 1
  })
  tags = var.tags
}

# -------------------------------------------------------
# EKS Add-on: Prometheus Node Exporter
# -------------------------------------------------------
data "aws_eks_addon_version" "prometheus_node_exporter_latest" {
  addon_name         = "prometheus-node-exporter"
  kubernetes_version = module.eks_cluster.eks-cluster-version
  most_recent        = true
}

resource "aws_eks_addon" "prometheus_node_exporter" {
  cluster_name                = module.eks_cluster.eks-cluster-id
  addon_name                  = "prometheus-node-exporter"
  addon_version               = data.aws_eks_addon_version.prometheus_node_exporter_latest.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

# -------------------------------------------------------
# EKS Add-on: Kube State Metrics
# -------------------------------------------------------
data "aws_eks_addon_version" "kube_state_metrics_latest" {
  addon_name         = "kube-state-metrics"
  kubernetes_version = module.eks_cluster.eks-cluster-version
  most_recent        = true
}

resource "aws_eks_addon" "kube_state_metrics" {
  cluster_name                = module.eks_cluster.eks-cluster-id
  addon_name                  = "kube-state-metrics"
  addon_version               = data.aws_eks_addon_version.kube_state_metrics_latest.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

# -------------------------------------------------------
# ADOT Collector K8s RBAC
# -------------------------------------------------------
resource "kubernetes_service_account_v1" "adot_collector" {
  metadata {
    name      = "adot-collector"
    namespace = "default"
    labels = {
      "app.kubernetes.io/name"      = "adot-collector"
      "app.kubernetes.io/component" = "opentelemetry-collector"
    }
  }
}

resource "kubernetes_cluster_role_v1" "otel_collector" {
  metadata {
    name = "otel-collector-cluster-role"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "services", "endpoints", "pods", "namespaces"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["replicasets", "deployments", "daemonsets", "statefulsets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    non_resource_urls = ["/metrics"]
    verbs             = ["get"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "otel_collector" {
  metadata {
    name = "otel-collector-cluster-role-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.otel_collector.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.adot_collector.metadata[0].name
    namespace = kubernetes_service_account_v1.adot_collector.metadata[0].namespace
  }
}
