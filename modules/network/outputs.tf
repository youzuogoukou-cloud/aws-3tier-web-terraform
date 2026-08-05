output "vpc_id" {
  description = "vpc id"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "subnet ids"
  value       = { for k, v in var.public_subnets : k => aws_subnet.public_subnet[k].id }
}

output "private_subnet_ids" {
  description = "subnet ids"
  value       = { for k, v in var.private_subnets : k => aws_subnet.private_subnet[k].id }
}