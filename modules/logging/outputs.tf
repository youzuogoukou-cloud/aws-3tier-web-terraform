output "ec2_accesslog_name" {
  value = aws_cloudwatch_log_group.ec2_accesslog.name
}

output "ec2_accesslog_arn" {
  value = aws_cloudwatch_log_group.ec2_accesslog.arn
}

output "ec2_errorlog_name" {
  value = aws_cloudwatch_log_group.ec2_errorlog.name
}

output "ec2_errorlog_arn" {
  value = aws_cloudwatch_log_group.ec2_errorlog.arn
}