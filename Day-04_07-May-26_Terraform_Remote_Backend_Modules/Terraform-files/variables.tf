variable "aws_region" {
  description = "The AWS region to create resources in."
  type        = string
  default     = "ap-south-1"
}

variable "tags" {
  description = "A map of tags to apply to all resources."
  type        = map(string)
  default     = { Owner = "chirag.tank@einfochips.com" }
}

variable "public_subnet_cidr" {
  description = "The CIDR block for the public subnet."
  type        = string
}

variable "private_subnet_cidr" {
  description = "The CIDR block for the private subnet."
  type        = string
}

variable "subnet_az" {
  description = "The availability zone for the subnets."
  type        = string
}

variable "sg_pub_ingress_cidrs" {
  description = "A list of CIDR blocks allowed to SSH into the public EC2 instance."
  type        = list(string)
}
