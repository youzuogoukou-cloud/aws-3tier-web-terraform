variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "project_name" {
  description = "project name"
  type        = string
}

variable "vpc_id" {
  description = "aws vpc id"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet ids to place the ALB in (requires two or more AZs)"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet ids the ASG launches EC2 instances into"
  type        = list(string)
}

variable "ec2_accesslog_name" {
  description = "Accesslog name for the CloudWatch to output logs"
  type        = string
}

variable "ec2_accesslog_arn" {
  description = "Accesslog ARN for the CloudWatch to output logs"
  type        = string
}

variable "ec2_errorlog_name" {
  description = "Errorlog name for the CloudWatch to output logs"
  type        = string
}

variable "ec2_errorlog_arn" {
  description = "Errorlog ARN for the CloudWatch to output logs"
  type        = string
}