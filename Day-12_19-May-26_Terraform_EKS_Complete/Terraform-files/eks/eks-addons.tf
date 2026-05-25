# EKS Add-On for Pod-Identity-Agent
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.eks_cluster.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = var.pia_latest
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.node-group
  ]
}

# EKS Add-On for EBS CSI Driver
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = aws_eks_cluster.eks_cluster.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.ebs_csi_latest
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = var.ebs_csi_role_arn

  depends_on = [
    aws_eks_node_group.node-group
  ]
} 

# Pod Identity Association
resource "aws_eks_pod_identity_association" "albc" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  namespace       = "kube-system"
  service_account = "alb-controller-sa"

  role_arn = var.albc_role_arn

  depends_on = [
    aws_eks_addon.pod_identity_agent
  ]
}

resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"

  role_arn = var.ebs_csi_role_arn

  depends_on = [
    aws_eks_addon.pod_identity_agent
  ]
}

