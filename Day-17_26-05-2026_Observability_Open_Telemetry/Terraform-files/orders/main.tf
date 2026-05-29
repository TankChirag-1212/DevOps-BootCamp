# Security Group for Orders RDS PostgreSQL
resource "aws_security_group" "rds_postgresql_sg" {
  name        = "${var.name}-rds-postgresql-sg"
  description = "Allow RDS PostgreSQL access from EKS cluster"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow RDS PostgreSQL from EKS Cluster"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-rds-postgresql-sg" })
}

# ------------------------------------------------------------
# Using existing RDS PostgreSQL instance (subnet group limit reached)
# To create a new RDS instance instead, comment the data block
# below and uncomment the subnet group + db instance resources
# ------------------------------------------------------------

# data "aws_db_instance" "orders_postgres" {
#   db_instance_identifier = "orders-postgres-db-anita"
# }

resource "aws_db_subnet_group" "rds_postgresql_subnet_group" {
  name        = "${var.name}-rds-postgresql-subnet-group"
  description = "Subnet group for Orders RDS PostgreSQL"
  subnet_ids  = var.subnet_ids
  tags        = merge(var.tags, { Name = "${var.name}-rds-postgresql-subnet-group" })
}

resource "aws_db_instance" "orders_postgres" {
  identifier              = "chirag-orders-postgres-db"
  engine                  = "postgres"
  engine_version          = "17.6"
  instance_class          = "db.t4g.micro"
  allocated_storage       = 20
  max_allocated_storage   = 100
  db_subnet_group_name    = aws_db_subnet_group.rds_postgresql_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_postgresql_sg.id]
  db_name                 = "ordersdb"
  username                = var.db_username
  password                = var.db_password
  port                    = 5432
  multi_az                = false
  storage_encrypted       = true
  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 7
  deletion_protection     = false
  tags                    = merge(var.tags, { Name = "${var.name}-orders-rds-postgres" })
}

# SQS Queue for Orders
resource "aws_sqs_queue" "orders_sqs_queue" {
  name                       = "${var.name}-orders-queue"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 30
  delay_seconds              = 0
  receive_wait_time_seconds  = 10
  tags                       = merge(var.tags, { Name = "${var.name}-orders-queue", Component = "Orders" })
}

# IAM Role for Orders Pod Identity (Secrets + SQS)
resource "aws_iam_role" "orders_postgresql_getsecrets" {
  name               = "${var.name}-orders-postgresql-getsecrets-role"
  assume_role_policy = var.assume_role_policy
  tags               = merge(var.tags, { Name = "${var.name}-orders-postgresql-getsecrets-role" })
}

# IAM Policy for SQS access
resource "aws_iam_policy" "orders_sqs_policy" {
  name        = "${var.name}-orders-sqs-policy"
  description = "Allow Orders microservice to interact with Amazon SQS and Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "OrdersSQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage",
          "sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:ListQueues", "sqs:PurgeQueue"
        ]
        Resource = aws_sqs_queue.orders_sqs_queue.arn
      },
      {
        Sid    = "OrdersSecretsManagerAccess"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:chirag-retailstore-db-secret*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "orders_sqs_policy_attach" {
  policy_arn = aws_iam_policy.orders_sqs_policy.arn
  role       = aws_iam_role.orders_postgresql_getsecrets.name
}

# Pod Identity Association for Orders
resource "aws_eks_pod_identity_association" "orders" {
  cluster_name    = var.eks_cluster_name
  namespace       = "default"
  service_account = "orders"
  role_arn        = aws_iam_role.orders_postgresql_getsecrets.arn
}
