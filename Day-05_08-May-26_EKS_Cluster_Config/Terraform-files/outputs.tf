# VPC Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_1_id" {
  description = "The ID of the first public subnet"
  value       = module.vpc.public_subnet_1_id
}

output "public_subnet_2_id" {
  description = "The ID of the second public subnet"
  value       = module.vpc.public_subnet_2_id
}

# EKS Cluster Outputs
output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks_cluster.eks-cluster-name
}

output "eks_cluster_endpoint" {
  description = "The endpoint of the EKS cluster"
  value       = module.eks_cluster.eks-cluster-endpoint
}

output "eks_cluster_version" {
  description = "The Kubernetes version of the EKS cluster"
  value       = module.eks_cluster.eks-cluster-version
}

output "eks_cluster_certificate_authority_data" {
  description = "The certificate authority data for the EKS cluster"
  value       = module.eks_cluster.eks-cluster-certificate-authority-data
  sensitive   = true
}

# EKS Node Group Outputs
output "eks_node_group_name" {
  description = "The name of the EKS node group"
  value       = module.eks_cluster.eks-node-group-name
}

output "eks_node_group_instance_role_arn" {
  description = "The ARN of the IAM role used by the EKS node group"
  value       = module.eks_cluster.eks-node-group-instance-role-arn
}

# Kubectl Configuration Command
output "configure_kubectl" {
  description = "Command to configure kubectl to connect to the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_cluster.eks-cluster-name}"
}
