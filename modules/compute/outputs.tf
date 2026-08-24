output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "ec2_sg_id" {
  value = aws_security_group.ec2_sg.id
}
