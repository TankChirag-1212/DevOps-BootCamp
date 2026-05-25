variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {
    Owner     = "chirag.tank@einfochips.com"
  }
}

variable "eks_addon_trust_policy" {
  description = "Trust policy for EKS add-on roles"
  type        = string
}

variable "albc_iam_policy" {
  description = "IAM policy for AWS Load Balancer Controller"
  type        = string
}

variable "karpenter_controller_policy" {
  description = "IAM policy for Karpenter controller"
  type        = string
}