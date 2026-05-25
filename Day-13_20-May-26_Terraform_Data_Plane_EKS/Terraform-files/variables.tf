variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "business_division" {
  description = "Business division used in resource names and tags"
  type        = string
  default     = "chirag"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Terraform = "true"
  }
}
