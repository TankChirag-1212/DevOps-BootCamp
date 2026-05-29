# ADOT Collector IAM Role (Pod Identity)
resource "aws_iam_role" "adot_collector" {
  name               = "${var.cluster_name}-adot-collector-role"
  assume_role_policy = data.aws_iam_policy_document.adot_collector_assume.json
}

data "aws_iam_policy_document" "adot_collector_assume" {
  statement {
    sid     = "PodIdentity"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# ADOT Collector IAM Policy
resource "aws_iam_policy" "adot_collector" {
  name        = "${var.name}-adot-collector-policy"
  description = "IAM policy for ADOT collector to send telemetry to CloudWatch and X-Ray"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents", "logs:CreateLogGroup", "logs:CreateLogStream",
          "logs:DescribeLogStreams", "logs:DescribeLogGroups"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/*",
          "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/*:*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:GetLogEvents", "logs:FilterLogEvents"]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/*",
          "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/*:*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments", "xray:PutTelemetryRecords",
          "xray:GetSamplingRules", "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "aps:RemoteWrite", "aps:QueryMetrics",
          "aps:GetSeries", "aps:GetLabels", "aps:GetMetricMetadata"
        ]
        Resource = var.amp_workspace_arn
      }
    ]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "adot_collector" {
  policy_arn = aws_iam_policy.adot_collector.arn
  role       = aws_iam_role.adot_collector.name
}

# ADOT Pod Identity Association
resource "aws_eks_pod_identity_association" "adot_collector" {
  cluster_name    = var.cluster_name
  namespace       = "default"
  service_account = "adot-collector"
  role_arn        = aws_iam_role.adot_collector.arn
  tags            = var.tags
}

# AMG IAM Policies
resource "aws_iam_policy" "amg_prometheus_policy" {
  name        = "${var.cluster_name}-amg-prometheus-policy"
  description = "IAM policy for Grafana to access Amazon Managed Prometheus"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "aps:ListWorkspaces", "aps:DescribeWorkspace", "aps:QueryMetrics",
        "aps:GetLabels", "aps:GetSeries", "aps:GetMetricMetadata"
      ]
      Resource = "*"
    }]
  })
  tags = var.tags
}

resource "aws_iam_policy" "amg_sns_policy" {
  name        = "${var.cluster_name}-amg-sns-policy"
  description = "IAM policy for Grafana to publish AWS SNS notifications"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = ["arn:aws:sns:*:${var.account_id}:grafana*"]
    }]
  })
  tags = var.tags
}

data "aws_iam_policy" "xray_readonly" {
  arn = "arn:aws:iam::aws:policy/AWSXrayReadOnlyAccess"
}

# AMG IAM Role
resource "aws_iam_role" "amg" {
  name        = "${var.cluster_name}-amg-service-role"
  description = "IAM role for Amazon Managed Grafana"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "grafana.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "amg_prometheus" {
  role       = aws_iam_role.amg.name
  policy_arn = aws_iam_policy.amg_prometheus_policy.arn
}

resource "aws_iam_role_policy_attachment" "amg_sns" {
  role       = aws_iam_role.amg.name
  policy_arn = aws_iam_policy.amg_sns_policy.arn
}

resource "aws_iam_role_policy_attachment" "amg_xray" {
  role       = aws_iam_role.amg.name
  policy_arn = data.aws_iam_policy.xray_readonly.arn
}
