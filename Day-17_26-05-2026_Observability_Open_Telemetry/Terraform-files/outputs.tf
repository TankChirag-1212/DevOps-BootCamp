# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = data.aws_vpc.main.id
}

output "public_subnet_1_id" {
  description = "ID of public subnet 1"
  value       = module.vpc.public_subnet_1_id
}

output "public_subnet_2_id" {
  description = "ID of public subnet 2"
  value       = module.vpc.public_subnet_2_id
}

# EKS Cluster Outputs
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks_cluster.eks-cluster-name
}

output "eks_cluster_endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = module.eks_cluster.eks-cluster-endpoint
}

output "eks_cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = module.eks_cluster.eks-cluster-version
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the EKS cluster"
  value       = module.eks_cluster.eks-cluster-certificate-authority-data
  sensitive   = true
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks_cluster.eks-cluster-security-group-id
}

# EKS Node Group Outputs
output "eks_node_group_name" {
  description = "Name of the EKS managed node group"
  value       = module.eks_cluster.eks-node-group-name
}

output "eks_node_group_role_arn" {
  description = "ARN of the IAM role used by the EKS node group"
  value       = module.iam.node_group_role_arn
}

# Kubectl Configuration Command
output "configure_kubectl" {
  description = "Run this command to configure kubectl for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_cluster.eks-cluster-name}"
}

# Karpenter

# output "karpenter_helm_metadata" {
#   description = "Metadata for Karpenter Controller Helm release"
#   value       = helm_release.karpenter.metadata
# }

# Catalog
output "catalog_rds_endpoint" {
  value = module.catalog.catalog_rds_endpoint
}

output "catalog_sa_getsecrets_role_arn" {
  value = module.catalog.catalog_sa_getsecrets_role_arn
}

output "catalog_sa_pod_identity_association_arn" {
  value = module.catalog.catalog_sa_pod_identity_association_arn
}

# Cart
output "cart_dynamodb_role_arn" {
  value = module.cart.cart_dynamodb_role_arn
}

output "cart_dynamodb_pod_identity_association_arn" {
  value = module.cart.cart_dynamodb_pod_identity_association_arn
}

# Checkout
output "checkout_redis_endpoint" {
  value = module.checkout.checkout_redis_endpoint
}

# Orders
output "orders_rds_postgresql_endpoint" {
  value = module.orders.orders_rds_postgresql_endpoint
}

output "orders_sqs_queue_url" {
  value = module.orders.orders_sqs_queue_url
}

output "orders_postgresql_sa_getsecrets_role_arn" {
  value = module.orders.orders_postgresql_sa_getsecrets_role_arn
}

output "orders_postgresql_sa_pod_identity_association_arn" {
  value = module.orders.orders_postgresql_sa_pod_identity_association_arn
}

# Observability - AMP
output "amp_workspace_id" {
  description = "AMP Workspace ID"
  value       = module.amp.amp_workspace_id
}

output "amp_endpoint" {
  description = "AMP Remote Write Endpoint"
  value       = module.amp.amp_endpoint
}

output "amp_query_endpoint" {
  description = "AMP Query Endpoint"
  value       = module.amp.amp_query_endpoint
}

# Observability - IAM
output "adot_collector_role_arn" {
  description = "IAM Role ARN for ADOT Collector"
  value       = module.observability_iam.adot_collector_role_arn
}

output "amg_iam_role_arn" {
  description = "ARN of the AMG IAM role"
  value       = module.observability_iam.amg_iam_role_arn
}

# Observability - AMG
output "amg_workspace_id" {
  description = "ID of the Grafana workspace"
  value       = module.amg.amg_workspace_id
}

output "amg_workspace_url" {
  description = "Full URL to access Grafana workspace"
  value       = module.amg.amg_workspace_url
}
