output "orders_rds_postgresql_endpoint" {
  value = data.aws_db_instance.orders_postgres.endpoint
  # value = aws_db_instance.orders_postgres.endpoint  # uncomment when creating new RDS
}

output "orders_rds_postgresql_db_name" {
  value = data.aws_db_instance.orders_postgres.db_name
  # value = aws_db_instance.orders_postgres.db_name  # uncomment when creating new RDS
}

output "orders_sqs_queue_url" {
  value = aws_sqs_queue.orders_sqs_queue.url
}

output "orders_sqs_queue_arn" {
  value = aws_sqs_queue.orders_sqs_queue.arn
}

output "orders_postgresql_sa_getsecrets_role_arn" {
  value = aws_iam_role.orders_postgresql_getsecrets.arn
}

output "orders_postgresql_sa_pod_identity_association_arn" {
  value = aws_eks_pod_identity_association.orders.association_arn
}
