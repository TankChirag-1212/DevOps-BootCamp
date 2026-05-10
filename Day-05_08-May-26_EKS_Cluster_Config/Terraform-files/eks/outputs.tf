output "eks-cluster-endpoint" {
  description = "The endpoint of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "eks-cluster-id" {
  description = "The ID of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.id
}

output "eks-cluster-name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.name
}

output "eks-cluster-version" {
  description = "The Kubernetes version of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.version
} 

output "eks-cluster-certificate-authority-data" {
  description = "The certificate authority data for the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}

output "eks-node-group-name" {
  description = "The name of the EKS node group"
  value       = aws_eks_node_group.node-group.node_group_name
}

output "eks-node-group-instance-role-arn" {
  description = "The ARN of the IAM role used by the EKS node group"
  value       = aws_iam_role.node_group_role.arn
}

# output "to_configure_kubectl" {
#   description = "Command to configure kubectl to connect to the EKS cluster"
#   value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.eks_cluster.name}"
# }