# Security Group for Catalog RDS MySQL
resource "aws_security_group" "rds_mysql_sg" {
  name        = "${var.name}-rds-mysql-sg"
  description = "Allow MySQL access from EKS cluster"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow MySQL from EKS cluster security group"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.eks_cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-rds-mysql-sg" })
}

# ------------------------------------------------------------
# Using existing RDS MySQL instance (subnet group limit reached)
# To create a new RDS instance instead, comment the data block
# below and uncomment the subnet group + db instance resources
# ------------------------------------------------------------

data "aws_db_instance" "catalog_rds" {
  db_instance_identifier = "mydb3-anita"
}

# resource "aws_db_subnet_group" "rds_subnet_group" {
#   name       = "${var.name}-rds-mysql-subnet-group"
#   subnet_ids = var.subnet_ids
#   tags       = merge(var.tags, { Name = "${var.name}-rds-mysql-subnet-group" })
# }

# resource "aws_db_instance" "catalog_rds" {
#   identifier               = "mydb3"
#   engine                   = "mysql"
#   engine_version           = "8.0"
#   instance_class           = "db.t3.micro"
#   allocated_storage        = 20
#   db_name                  = "catalogdb"
#   username                 = var.db_username
#   password                 = var.db_password
#   db_subnet_group_name     = aws_db_subnet_group.rds_subnet_group.name
#   vpc_security_group_ids   = [aws_security_group.rds_mysql_sg.id]
#   skip_final_snapshot      = true
#   publicly_accessible      = false
#   delete_automated_backups = true
#   multi_az                 = false
#   backup_retention_period  = 1
#   tags                     = merge(var.tags, { Name = "${var.name}-catalog-rds-mysql" })
# }

# IAM Policy for Secrets Manager access
resource "aws_iam_policy" "retailstore_db_secret_policy" {
  name        = "${var.name}-retailstore-db-secret-policy"
  description = "Allows access to retailstore-db-secret* in AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:chirag-retailstore-db-secret*"
    }]
  })
}

# IAM Role for Catalog Pod Identity (Secrets Store CSI Driver)
resource "aws_iam_role" "catalog_getsecrets" {
  name               = "${var.name}-catalog-getsecrets-role"
  assume_role_policy = var.assume_role_policy
  tags               = merge(var.tags, { Name = "${var.name}-catalog-getsecrets-role" })
}

resource "aws_iam_role_policy_attachment" "catalog_db_secret_attach" {
  policy_arn = aws_iam_policy.retailstore_db_secret_policy.arn
  role       = aws_iam_role.catalog_getsecrets.name
}

# Pod Identity Association for Catalog
resource "aws_eks_pod_identity_association" "catalog" {
  cluster_name    = var.eks_cluster_name
  namespace       = "default"
  service_account = "catalog"
  role_arn        = aws_iam_role.catalog_getsecrets.arn
}
