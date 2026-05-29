output "amg_workspace_id" {
  description = "ID of the Grafana workspace"
  value       = aws_grafana_workspace.main.id
}

output "amg_workspace_arn" {
  description = "ARN of the Grafana workspace"
  value       = aws_grafana_workspace.main.arn
}

output "amg_workspace_url" {
  description = "Full URL to access Grafana workspace"
  value       = "https://${aws_grafana_workspace.main.endpoint}"
}
