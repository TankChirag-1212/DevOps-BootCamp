resource "aws_sqs_queue" "karpenter_interruption" {
  name                     = var.eks_cluster_name
  message_retention_seconds = 300
  sqs_managed_sse_enabled  = true
  
  tags = var.tags
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.url
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = ["events.amazonaws.com", "sqs.amazonaws.com"]
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter_interruption.arn
      },
      {
        Sid      = "DenyHTTP"
        Effect   = "Deny"
        Action   = "sqs:*"
        Resource = aws_sqs_queue.karpenter_interruption.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
        Principal = "*"
      }
    ]
  })
}

# -------------------- EventBridge ----------------------- #

# AWS Health Events → SQS

resource "aws_cloudwatch_event_rule" "karpenter_health_event" {
  name        = "chirag-eks-cluster-k-health"
  description = "AWS Health Event → Karpenter Interruption Queue"

  event_pattern = jsonencode({
    source       = ["aws.health"]
    "detail-type" = ["AWS Health Event"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "karpenter_health_target" {
  rule      = aws_cloudwatch_event_rule.karpenter_health_event.name
  target_id = "KarpenterHealthTarget"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

# EC2 Spot Interruption Warning → SQS

resource "aws_cloudwatch_event_rule" "karpenter_spot_interrupt" {
  name        = "chirag-eks-cluster-k-spot"
  description = "EC2 Spot Interruption Warning → Karpenter SQS Queue"

  event_pattern = jsonencode({
    source       = ["aws.ec2"]
    "detail-type" = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "karpenter_spot_target" {
  rule      = aws_cloudwatch_event_rule.karpenter_spot_interrupt.name
  target_id = "KarpenterSpotTarget"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

# EC2 Instance Rebalance Recommendation → SQS

resource "aws_cloudwatch_event_rule" "karpenter_rebalance" {
  name        = "chirag-eks-cluster-k-rebal"
  description = "EC2 Instance Rebalance Recommendation → Karpenter SQS Queue"

  event_pattern = jsonencode({
    source       = ["aws.ec2"]
    "detail-type" = ["EC2 Instance Rebalance Recommendation"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "karpenter_rebalance_target" {
  rule      = aws_cloudwatch_event_rule.karpenter_rebalance.name
  target_id = "KarpenterRebalanceTarget"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

# EC2 Instance State-change Notification → SQS

resource "aws_cloudwatch_event_rule" "karpenter_instance_state" {
  name        = "chirag-eks-cluster-k-state"
  description = "EC2 Instance State Change Notification → Karpenter SQS Queue"

  event_pattern = jsonencode({
    source       = ["aws.ec2"]
    "detail-type" = ["EC2 Instance State-change Notification"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "karpenter_instance_state_target" {
  rule      = aws_cloudwatch_event_rule.karpenter_instance_state.name
  target_id = "KarpenterStateTarget"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}