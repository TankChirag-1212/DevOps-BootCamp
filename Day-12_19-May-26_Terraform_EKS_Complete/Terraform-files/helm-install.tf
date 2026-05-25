# Helm install for AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name            = "aws-load-balancer-controller"
  repository      = "https://aws.github.io/eks-charts"
  chart           = "aws-load-balancer-controller"
  namespace       = "kube-system"
  # upgrade_install = true

  set = [
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "alb-controller-sa"
    },
    {
      name  = "clusterName"
      value = module.eks_cluster.eks-cluster-id
    },
    {
      name  = "vpcId"
      value = data.aws_vpc.main.id
    },
    {
      name  = "region"
      value = var.aws_region
    }
  ]

  depends_on = [module.eks_cluster]
}

# Install Secrets Store CSI Driver
resource "helm_release" "secrets_store_csi_driver" {
  name            = "csi-secrets-store"
  repository      = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart           = "secrets-store-csi-driver"
  namespace       = "kube-system"
  # upgrade_install = true
  wait            = true
  timeout         = 600
  cleanup_on_fail = true

  set = [
    {
      name  = "syncSecret.enabled"
      value = "true"
    },
    {
      name  = "tokenRequests[0].audience"
      value = "pods.eks.amazonaws.com"
    },
  ]

  depends_on = [module.eks_cluster]
}

# Install AWS Secrets and Configuration Provider (ASCP)
resource "helm_release" "aws_secrets_provider" {
  name            = "secrets-provider-aws"
  repository      = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart           = "secrets-store-csi-driver-provider-aws"
  namespace       = "kube-system"
  # upgrade_install = true
  wait            = true
  timeout         = 600
  cleanup_on_fail = true

  set = [
    {
      name  = "secrets-store-csi-driver.install"
      value = "false"
    }
  ]

  depends_on = [
    module.eks_cluster,
    helm_release.secrets_store_csi_driver
  ]
}
