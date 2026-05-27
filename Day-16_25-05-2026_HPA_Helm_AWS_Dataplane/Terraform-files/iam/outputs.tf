output "eks_cluster_role_arn" {
  description = "The ARN of the IAM role used by the EKS cluster"
  value       =  aws_iam_role.eks_cluster_role.arn 
}

output "node_group_role_arn" {
  description = "The ARN of the IAM role used by the EKS node group"
  value       = aws_iam_role.node_group_role.arn
}

# output for AWS Load Balancer Controller

output "albc_role_arn" {
  description = "The ARN of the IAM role used by the AWS Load Balancer Controller"
  value       = aws_iam_role.albc_role.arn
}

output "albc_policy_arn" {
  description = "The ARN of the IAM policy used by the AWS Load Balancer Controller"
  value       = aws_iam_policy.albc_policy.arn
}


# Output for EBS CSI Driver

output "ebs_csi_role_arn" {
  description = "The ARN of the IAM role used by the EBS CSI Driver"
  value       = aws_iam_role.ebs_csi_driver_role.arn
}

# Karpenter Controller IAM Role Outputs
output "karpenter_controller_role_arn" {
  description = "IAM role ARN for the Karpenter controller"
  value       = aws_iam_role.karpenter_controller_role.arn
}

output "karpenter_node_role_arn" {
  description = "IAM Role ARN used by EC2 nodes launched by Karpenter"
  value       = aws_iam_role.karpenter_node_role.arn
}