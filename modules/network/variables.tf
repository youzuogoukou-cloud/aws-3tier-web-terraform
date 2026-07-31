variable "region" {
  description = "aws region"
  type        = string
}

variable "vpc_cidr_block" {
  description = "aws vpc cidr block"
  type        = string
}

variable "subnets" {
  description = "aws public subnet cidr block"
  type        = map(string)
}

variable "project_name" {
  description = "project name"
  type        = string
}
