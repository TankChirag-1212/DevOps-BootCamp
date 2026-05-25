output "cart_dynamodb_policy_arn" {
  value = aws_iam_policy.cart_dynamodb_policy.arn
}

output "cart_dynamodb_role_arn" {
  value = aws_iam_role.cart_dynamodb_role.arn
}

output "cart_dynamodb_pod_identity_association_arn" {
  value = aws_eks_pod_identity_association.cart_pod_identity.association_arn
}

output "cart_dynamodb_table_name" {
  value = aws_dynamodb_table.items.name
}
