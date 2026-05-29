variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "name" {
  description = "Naming prefix (e.g. division-env)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "amp_workspace_arn" {
  description = "ARN of the AMP workspace (for ADOT policy)"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
