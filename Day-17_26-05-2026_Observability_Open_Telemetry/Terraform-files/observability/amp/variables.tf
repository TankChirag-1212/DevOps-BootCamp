variable "cluster_name" {
  description = "EKS cluster name used for AMP workspace alias"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
