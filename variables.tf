variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "region" {
  description = "aws region"
  type        = string
  default     = "ap-northeast-1"
}

variable "vpc_cidr_block" {
  description = "aws vpc cidr block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "aws public subnet cidr block"
  type        = map(string)
  default = {
    a = "10.0.101.0/24"
    c = "10.0.102.0/24"
  }
}

variable "private_subnets" {
  description = "aws private subnet cidr block"
  type        = map(string)
  default = {
    a = "10.0.1.0/24"
    c = "10.0.2.0/24"
  }
}

variable "project_name" {
  description = "project name"
  type        = string
  default     = "portfolio-web"
}

