variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {
    Owner       = "chirag.tank@einfchips.com"
  }
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for public subnet 1"
  type        = string
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for public subnet 2"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy the EKS cluster and other resources"
  type        = string
}