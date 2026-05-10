variable "aws_region" {
  description = "AWS region to deploy the EKS cluster and other resources"
  type        = string
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for public subnet 1"
  type        = string
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for public subnet 2"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Owner = "chiragtank@einfochips.com"
  }
}

variable "eks_version" {
  description = "The Kubernetes version for the EKS cluster"
  type        = string
}

variable "service_ipv4_cidr" {
  description = "CIDR block for Kubernetes service IPs"
  type        = string
}

variable "my_ip_cidr" {
  description = "CIDR block for your IP address to allow access to the EKS API server"
  type        = string
}

variable "node_group_instance_type" {
  description = "The EC2 instance type for the EKS node group"
  type        = list(string)
}

variable "node_disk_size" {
  description = "The disk size (in GB) for the EKS node group instances"
  type        = number
}

