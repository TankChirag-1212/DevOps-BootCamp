resource "aws_iam_policy" "karpenter_controller_policy" {
  name        = "${var.eks_cluster_name}-karpenter_controller_policy"
  description = "karpenter controller IAM policy"
  policy      = var.karpenter_controller_policy
  tags        = var.tags
}

resource "aws_iam_role" "karpenter_controller_role" {
  name               = "${var.eks_cluster_name}-karpenter_controller_role"
  description        = "karpenter controller IAM role"
  assume_role_policy = var.eks_addon_trust_policy
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_policy" {
  policy_arn = aws_iam_policy.karpenter_controller_policy.arn
  role       = aws_iam_role.karpenter_controller_role.name
}
