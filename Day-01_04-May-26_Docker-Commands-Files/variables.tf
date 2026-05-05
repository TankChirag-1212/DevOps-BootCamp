variable "key_pair_name" {
  description = "Name of the existing AWS key pair to use for SSH access"
  type        = string
}

variable "ami_id_amd64" {
  description = "Name of the existing AWS key pair to use for SSH access"
  type        = string
}

variable "My_IP" {
  description = "My ip address for security group inbound rules"
  type        = string
}

variable "Office_IP" {
  description = "My ip address at Office for security group inbound rules"
  type        = string
}

# Variables for Default Tags of all resources

variable "Owner" {
  description = "owner email id for tags"
  default     = "chirag.tank@einfochips.com"
  type        = string
}

variable "Department" {
  description = "Department name for tags"
  default     = "PES-Digital"
  type        = string
}

variable "Project_Name" {
  description = "project name for tags"
  default     = "DevOps_BootCamp"
  type        = string
}

variable "End_Date" {
  description = "date of resource created for tags"
  default     = "04-05-2026"
  type        = string
}