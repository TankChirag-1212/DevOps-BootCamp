variable "eks_version" {
  description = "The Kubernetes version for the EKS cluster"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {
    Owner     = "chirag.tank@einfochips.com"
  }
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

