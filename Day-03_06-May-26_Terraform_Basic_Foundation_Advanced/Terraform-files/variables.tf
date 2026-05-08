variable "aws_region" {
  description = "The AWS region to create resources in."
  type        = string
  default     = "ap-south-1"
}

# variable "vpc_id" {
#   description = "The ID of the VPC where resources will be created."
#   type        = string
# }

variable "tags" {
  description = "A map of tags to apply to resources."
  type        = map(string)
  default = {
    Owner = "chirag.tank@einfochips.com"
  }
}

variable "public_subnet_cidr" {
  description = "The CIDR block for the public subnet."
  type        = string
}

variable "subnet_az" {
  description = "The availability zone for the public and private subnets."
  type        = string
}

# variable "private_subnet_cidr" {
#   description = "The CIDR block for the private subnet."
#   type        = string
# }

variable "sg-pub-ingress-cidrs" {
  description = "A list of CIDR blocks allowed to access the public security group."
  type        = list(string)
}
