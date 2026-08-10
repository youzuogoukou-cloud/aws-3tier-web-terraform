variable "project_name" {
  description = "project name"
  type        = string
}

variable "vpc_id" {
  description = "aws vpc id"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet ids to place the RDS"
  type        = list(string)
}

variable "ec2_sg_id" {
  description = "EC2 security group id"
  type        = string
}