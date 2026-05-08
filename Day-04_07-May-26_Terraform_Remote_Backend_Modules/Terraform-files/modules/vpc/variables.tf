variable "tags" {
  description = "A map of tags to apply to all resources."
  type        = map(string)
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
