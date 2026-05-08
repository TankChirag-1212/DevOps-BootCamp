output "vpc_id" {
  description = "The ID of the VPC where resources are created."
  value       = data.aws_vpc.vpc.id
}

# output "nat_gateway_id" {
#   description = "The ID of the NAT Gateway used for private subnet routing."
#   value       = data.aws_nat_gateway.nat.id
# }

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway attached to the VPC."
  value       = data.aws_internet_gateway.igw.id
}

output "public_route_table_id" {
  description = "The ID of the public route table associated with the public subnet."
  value       = data.aws_route_table.rtb-pub.id
}

# output "private_route_table_id" {
#   description = "The ID of the private route table associated with the private subnet."
#   value       = aws_route_table.rtb-priv.id
# }

output "public_subnet_id" {
  description = "The ID of the public subnet created in the VPC."
  value       = aws_subnet.subnet-pub.id
}

# output "private_subnet_id" {
#   description = "The ID of the private subnet created in the VPC."
#   value       = aws_subnet.subnet-priv.id
# }

output "public_ec2_id" {
  description = "The ID of the public EC2 instance."
  value       = aws_instance.ec2-public.id
}

# output "private_ec2_id" {
#   description = "The ID of the private EC2 instance."
#   value       = aws_instance.ec2-private.id
# }

output "key_pair_name" {
  description = "The name of the key pair used for EC2 instances."
  value       = data.aws_key_pair.key.key_name
}