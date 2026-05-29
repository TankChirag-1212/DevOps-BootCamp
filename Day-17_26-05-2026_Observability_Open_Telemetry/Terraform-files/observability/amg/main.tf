resource "aws_grafana_workspace" "main" {
  name                     = "${var.cluster_name}-amg"
  description              = "Grafana workspace for ${var.cluster_name} EKS cluster monitoring"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "CUSTOMER_MANAGED"
  role_arn                 = var.amg_role_arn
  data_sources             = ["PROMETHEUS", "CLOUDWATCH", "XRAY"]
  notification_destinations = ["SNS"]

  configuration = jsonencode({
    plugins         = { pluginAdminEnabled = true }
    unifiedAlerting = { enabled = true }
  })
  tags = var.tags
}
