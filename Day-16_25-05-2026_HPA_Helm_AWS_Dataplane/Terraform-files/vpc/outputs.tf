output "public_subnet_1_id" {
  description = "The ID of the first public subnet"
  value       = aws_subnet.pub_sub_1.id
}

output "public_subnet_2_id" {
  description = "The ID of the second public subnet"
  value       = aws_subnet.pub_sub_2.id
}