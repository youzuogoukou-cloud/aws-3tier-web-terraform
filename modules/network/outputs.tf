output "vpc_id" {
  description = "vpc id"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet ids keyed by AZ suffix"
  value       = { for k, v in var.public_subnets : k => aws_subnet.public_subnet[k].id }
}

output "private_subnet_ids" {
  description = "Private subnet ids keyed by AZ suffix"
  value       = { for k, v in var.private_subnets : k => aws_subnet.private_subnet[k].id }
}

output "s3_prefix_list_id" {
  description = "S3 prefix list id for the EC2 sg from EC2 to S3"
  value       = aws_vpc_endpoint.vpc_endpoint_s3.prefix_list_id
}