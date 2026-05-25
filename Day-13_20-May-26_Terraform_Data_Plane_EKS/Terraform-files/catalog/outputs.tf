output "catalog_rds_endpoint" {
  description = "RDS endpoint for Catalog microservice"
  value       = data.aws_db_instance.catalog_rds.address
  # value     = aws_db_instance.catalog_rds.address  # uncomment when creating new RDS
}

output "catalog_rds_sg_id" {
  value = aws_security_group.rds_mysql_sg.id
}

output "catalog_sa_getsecrets_role_arn" {
  description = "IAM Role ARN for Catalog to access Secrets Manager"
  value       = aws_iam_role.catalog_getsecrets.arn
}

output "catalog_sa_pod_identity_association_arn" {
  value = aws_eks_pod_identity_association.catalog.association_arn
}
