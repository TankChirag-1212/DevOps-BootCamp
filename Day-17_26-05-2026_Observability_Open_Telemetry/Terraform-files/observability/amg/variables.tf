variable "cluster_name" {
  description = "EKS cluster name used for Grafana workspace naming"
  type        = string
}

variable "amg_role_arn" {
  description = "IAM role ARN for the Grafana workspace"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
