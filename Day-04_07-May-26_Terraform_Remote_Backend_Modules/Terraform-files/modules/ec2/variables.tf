variable "tags" {
  description = "A map of tags to apply to all resources."
  type        = map(string)
}

variable "vpc_id" {
  description = "The ID of the VPC where security groups will be created."
  type        = string
}

variable "public_subnet_id" {
  description = "The ID of the public subnet for the public EC2 instance."
  type        = string
}

variable "private_subnet_id" {
  description = "The ID of the private subnet for the private EC2 instance."
  type        = string
}

variable "sg_pub_ingress_cidrs" {
  description = "A list of CIDR blocks allowed to SSH into the public EC2 instance."
  type        = list(string)
}
