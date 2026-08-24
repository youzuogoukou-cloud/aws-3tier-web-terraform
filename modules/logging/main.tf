resource "aws_cloudwatch_log_group" "ec2_accesslog" {
  name              = "${var.project_name}/ec2/accesslog"
  retention_in_days = 90

  tags = { Name = "${var.project_name}_ec2_accesslog" }
}

resource "aws_cloudwatch_log_group" "ec2_errorlog" {
  name              = "${var.project_name}/ec2/errorlog"
  retention_in_days = 90

  tags = { Name = "${var.project_name}_ec2_errorlog" }
}