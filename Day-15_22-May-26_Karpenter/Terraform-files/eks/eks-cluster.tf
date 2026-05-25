resource "aws_eks_cluster" "eks_cluster" {
  name     = "chirag-eks-cluster"
  role_arn = var.eks_cluster_role_arn

  version = var.eks_version

  vpc_config {
    subnet_ids = var.public_subnet_ids
    public_access_cidrs = [var.my_ip_cidr] # Restrict API server access to your IP for security
    endpoint_public_access = true
    endpoint_private_access = true
  }

  tags = var.tags

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  kubernetes_network_config {
    service_ipv4_cidr = var.service_ipv4_cidr
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true  
  }
}

# this will grant admin permissions to the user who creates the cluster (in this case me as I'll be using access keys to create resources via terraform), allowing them to manage the cluster using kubectl without needing additional IAM policies


# to fetch the IAM user details
# data "aws_iam_user" "my-iam-user-data" {
#     user_name = "chirag.tank@einfochips.com"
# }

# # to create the IAM Access Entry for the user to access the EKS cluster
# resource "aws_eks_access_entry" "admin_access" {
#   cluster_name = aws_eks_cluster.eks_cluster.name
#   principal_arn = data.aws_iam_user.my-iam-user-data.arn
#   type = "STANDARD"
# }


# # to associate the admin access policy with the user for cluster administration
# resource "aws_eks_access_policy_association" "admin_user_policy" {
#   cluster_name = aws_eks_cluster.eks_cluster.name
#   principal_arn = data.aws_iam_user.my-iam-user-data.arn
#   policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

#   access_scope {
#     type = "cluster"
#   }
# }