# IAM custom policy for AWS Load Balancer Controller
resource "aws_iam_policy" "albc_policy" {
    name = "chirag-AWSLoadBalancerControllerIAMPolicy"
    path = "/"
    description = "IAM policy for AWS Load Balancer Controller"
    policy = var.albc_iam_policy
}

# IAM role for AWS Load Balancer Controller
resource "aws_iam_role" "albc_role" {
    name = "chirag-alb-controller-role"
    assume_role_policy = var.eks_addon_trust_policy
    description = "IAM role for AWS Load Balancer Controller"

    tags = var.tags
}

# Attach the custom policy to the IAM role
resource "aws_iam_role_policy_attachment" "albc_policy_attachment" {
    role = aws_iam_role.albc_role.name
    policy_arn = aws_iam_policy.albc_policy.arn
}
