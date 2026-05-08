output "vpc_id" {
  description = "The ID of the fetched VPC."
  value       = data.aws_vpc.vpc.id
}

output "public_subnet_id" {
  description = "The ID of the created public subnet."
  value       = aws_subnet.subnet-pub.id
}

output "private_subnet_id" {
  description = "The ID of the created private subnet."
  value       = aws_subnet.subnet-priv.id
}

output "internet_gateway_id" {
  description = "The ID of the existing Internet Gateway."
  value       = data.aws_internet_gateway.igw.id
}

output "nat_gateway_id" {
  description = "The ID of the existing NAT Gateway."
  value       = data.aws_nat_gateway.nat.id
}

output "public_route_table_id" {
  description = "The ID of the existing public route table."
  value       = data.aws_route_table.rtb-pub.id
}

output "private_route_table_id" {
  description = "The ID of the created private route table."
  value       = aws_route_table.rtb-priv.id
}
