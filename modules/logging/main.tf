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

resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  name              = "${var.project_name}/vpc/flow/log"
  retention_in_days = 90

  tags = { Name = "${var.project_name}_vpc_flow_log" }
}

resource "aws_iam_role" "flow_log" {
  name = "${var.project_name}_flow_log"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Condition = {
          StringEquals = { "aws:SourceAccount" = var.account_id }
          ArnLike      = { "aws:SourceArn" = "arn:aws:ec2:${var.region}:${var.account_id}:vpc-flow-log/*" }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "flow_log" {
  name = "${var.project_name}_flow_log_logs"
  role = aws_iam_role.flow_log.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ],
        "Resource" : "*",
      }
    ]
  })
}

resource "aws_flow_log" "flow_log" {
  iam_role_arn         = aws_iam_role.flow_log.arn
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_log.arn
  traffic_type         = "ALL"
  vpc_id               = var.vpc_id
}