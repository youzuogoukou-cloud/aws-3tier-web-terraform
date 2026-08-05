output "instance_id" {
  value = aws_instance.ec2.id
}

output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}