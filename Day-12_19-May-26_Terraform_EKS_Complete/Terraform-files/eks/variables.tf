variable "eks_version" {
  description = "The Kubernetes version for the EKS cluster"
  type        = string
}

variable "eks_cluster_role_arn" {
  description = "The ARN of the IAM role to be used by the EKS cluster"
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

variable "node_group_role_arn" {
  description = "The ARN of the IAM role to be used by the EKS node group"
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

variable "pia_latest" {
  description = "Latest eks-pod-identity-agent addon version compatible with the EKS cluster version"
  type        = string
}

variable "ebs_csi_latest" {
  description = "Latest aws-ebs-csi-driver addon version compatible with the EKS cluster version"
  type        = string
}

variable "albc_role_arn" {
  description = "The ARN of the IAM role to be used by the ALB controller"
  type        = string
}

variable "ebs_csi_role_arn" {
  description = "The ARN of the IAM role to be used by the EBS CSI driver"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the EKS cluster will be created"
  type        = string
}

variable "aws_region" {
  description = "The AWS region where the EKS cluster will be created"
  type        = string
}