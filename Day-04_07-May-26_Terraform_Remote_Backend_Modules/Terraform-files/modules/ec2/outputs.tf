output "public_ec2_id" {
  description = "The ID of the public EC2 instance."
  value       = aws_instance.ec2-public.id
}

output "private_ec2_id" {
  description = "The ID of the private EC2 instance."
  value       = aws_instance.ec2-private.id
}

output "key_pair_name" {
  description = "The name of the key pair used for EC2 instances."
  value       = data.aws_key_pair.key.key_name
}

output "public_sg_id" {
  description = "The ID of the public security group."
  value       = aws_security_group.sg-pub.id
}

output "private_sg_id" {
  description = "The ID of the private security group."
  value       = aws_security_group.sg-priv.id
}
