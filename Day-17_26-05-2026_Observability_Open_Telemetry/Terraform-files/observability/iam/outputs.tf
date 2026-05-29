output "adot_collector_role_arn" {
  description = "IAM Role ARN for ADOT Collector"
  value       = aws_iam_role.adot_collector.arn
}

output "amg_iam_role_arn" {
  description = "ARN of the AMG IAM role"
  value       = aws_iam_role.amg.arn
}

output "amg_iam_role_name" {
  description = "Name of the AMG service role"
  value       = aws_iam_role.amg.name
}
