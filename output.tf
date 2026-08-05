output "ec2_instance_id" {
  value = module.compute.instance_id
}

output "alb_dns_name" {
  value = module.compute.alb_dns_name
}
