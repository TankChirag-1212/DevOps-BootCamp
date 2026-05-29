resource "aws_prometheus_workspace" "amp" {
  alias = "${var.cluster_name}-amp"
  tags  = var.tags
}
