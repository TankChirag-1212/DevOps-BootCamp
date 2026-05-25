variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

# variable "subnet_ids" {
#   type = list(string)
# }

variable "eks_cluster_name" {
  type = string
}

variable "eks_cluster_security_group_id" {
  type = string
}

variable "assume_role_policy" {
  type = string
}

# variable "db_username" {
#   type      = string
#   sensitive = true
# }

# variable "db_password" {
#   type      = string
#   sensitive = true
# }

variable "aws_region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "tags" {
  type = map(string)
}
