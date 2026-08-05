variable "region" {
  description = "aws region"
  type        = string
}

variable "vpc_cidr_block" {
  description = "aws vpc cidr block"
  type        = string
}

variable "public_subnets" {
  description = "aws public subnet cidr block"
  type        = map(string)
}

variable "private_subnets" {
  description = "aws private subnet cidr block"
  type        = map(string)
}

variable "project_name" {
  description = "project name"
  type        = string
}
