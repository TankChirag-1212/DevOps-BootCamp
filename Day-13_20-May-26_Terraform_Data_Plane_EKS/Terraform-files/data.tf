data "aws_caller_identity" "current" {}

# Remote state from Day-12 EKS project
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "chirag-tank-bootcamp-454143665149-ap-south-1-an"
    key    = "dev/eks/terraform.tfstate"
    region = "ap-south-1"
  }
}

# Fetch existing VPC (created in Day-12)
data "aws_vpc" "main" {
  tags = {
    Name = "Bootcamp-vpc-do-not-delete-vpc"
  }
}

# Fetch public subnets (only 2 public subnets exist, no private subnets)
data "aws_subnet" "pub_sub_1" {
  tags = {
    Name = "Chirag-bootcamp-pub-sub-1"
  }
}

data "aws_subnet" "pub_sub_2" {
  tags = {
    Name = "Chirag-bootcamp-pub-sub-2"
  }
}

# Pod Identity trust policy (shared across all microservice IAM roles)
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole", "sts:TagSession"]
  }
}

# Fetch DB credentials from Secrets Manager (created manually)
data "aws_secretsmanager_secret" "retailstore_secret" {
  name = "chirag-retailstore-db-secret"
}

data "aws_secretsmanager_secret_version" "retailstore_secret_value" {
  secret_id = data.aws_secretsmanager_secret.retailstore_secret.id
}
