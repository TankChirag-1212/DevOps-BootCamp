# IAM Policy for DynamoDB access
resource "aws_iam_policy" "cart_dynamodb_policy" {
  name        = "${var.name}-cart-dynamodb-policy"
  description = "Allow Cart microservice full access to DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:CreateTable", "dynamodb:DeleteTable", "dynamodb:DescribeTable",
        "dynamodb:UpdateTable", "dynamodb:PutItem", "dynamodb:GetItem",
        "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan",
        "dynamodb:UpdateItem", "dynamodb:BatchGetItem", "dynamodb:BatchWriteItem",
        "dynamodb:DescribeTimeToLive", "dynamodb:ListTables", "dynamodb:ListTagsOfResource"
      ]
      Resource = "*"
    }]
  })
}

# IAM Role for Cart Pod Identity
resource "aws_iam_role" "cart_dynamodb_role" {
  name               = "${var.name}-cart-dynamodb-role"
  assume_role_policy = var.assume_role_policy
  tags               = merge(var.tags, { Name = "${var.name}-cart-dynamodb-role" })
}

resource "aws_iam_role_policy_attachment" "cart_dynamodb_policy_attach" {
  policy_arn = aws_iam_policy.cart_dynamodb_policy.arn
  role       = aws_iam_role.cart_dynamodb_role.name
}

# Pod Identity Association for Cart
resource "aws_eks_pod_identity_association" "cart_pod_identity" {
  cluster_name    = var.eks_cluster_name
  namespace       = "default"
  service_account = "carts"
  role_arn        = aws_iam_role.cart_dynamodb_role.arn
}

# DynamoDB Table in ap-south-1
resource "aws_dynamodb_table" "items" {
  name         = "chirag-Items"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "customerId"
    type = "S"
  }

  global_secondary_index {
    name            = "idx_global_customerId"
    hash_key        = "customerId"
    projection_type = "ALL"
  }

  tags = merge(var.tags, { Name = "Items", Component = "Cart" })
}
