output "vpc_id" {
  description = "vpc id"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "subnet ids"
  value       = { for k, v in var.subnets : k => aws_subnet.public_subnet[k].id }
}