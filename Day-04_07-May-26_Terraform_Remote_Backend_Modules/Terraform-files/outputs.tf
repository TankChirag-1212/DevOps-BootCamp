output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "The ID of the public subnet."
  value       = module.vpc.public_subnet_id
}

output "private_subnet_id" {
  description = "The ID of the private subnet."
  value       = module.vpc.private_subnet_id
}

output "public_ec2_id" {
  description = "The ID of the public EC2 instance."
  value       = module.ec2.public_ec2_id
}

output "private_ec2_id" {
  description = "The ID of the private EC2 instance."
  value       = module.ec2.private_ec2_id
}

output "key_pair_name" {
  description = "The key pair used for EC2 instances."
  value       = module.ec2.key_pair_name
}
