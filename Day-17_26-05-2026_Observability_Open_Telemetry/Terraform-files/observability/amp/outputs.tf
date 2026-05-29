output "amp_workspace_id" {
  description = "AMP Workspace ID"
  value       = aws_prometheus_workspace.amp.id
}

output "amp_workspace_arn" {
  description = "AMP Workspace ARN"
  value       = aws_prometheus_workspace.amp.arn
}

output "amp_endpoint" {
  description = "AMP Remote Write Endpoint"
  value       = "${aws_prometheus_workspace.amp.prometheus_endpoint}api/v1/remote_write"
}

output "amp_query_endpoint" {
  description = "AMP Query Endpoint"
  value       = "${aws_prometheus_workspace.amp.prometheus_endpoint}api/v1/query"
}
