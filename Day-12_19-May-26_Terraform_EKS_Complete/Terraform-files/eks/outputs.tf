output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "eks-cluster-endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "eks-cluster-id" {
  description = "ID of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.id
}

output "eks-cluster-name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.name
}

output "eks-cluster-version" {
  description = "Kubernetes version of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.version
}

output "eks-cluster-certificate-authority-data" {
  description = "Base64-encoded certificate authority data for the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.certificate_authority[0].data
  sensitive   = true
}

output "eks-node-group-name" {
  description = "Name of the EKS managed node group"
  value       = aws_eks_node_group.node-group.node_group_name
}

output "eks-cluster-security-group-id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
}

output "ebs_csi_addon_arn" {
  description = "ARN of the EBS CSI driver addon"
  value       = aws_eks_addon.ebs_csi_driver.arn
}

output "pia_addon_arn" {
  description = "ARN of the Pod Identity Agent addon"
  value       = aws_eks_addon.pod_identity_agent.arn
}

output "lbc_pod_identity_association_arn" {
  description = "ARN of the ALB Controller Pod Identity Association"
  value       = aws_eks_pod_identity_association.albc.association_arn
}

output "ebs_csi_pod_identity_association_arn" {
  description = "ARN of the EBS CSI Driver Pod Identity Association"
  value       = aws_eks_pod_identity_association.ebs_csi.association_arn
}
