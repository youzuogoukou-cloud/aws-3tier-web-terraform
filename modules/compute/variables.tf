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

variable "subnet_id" {
  description = "aws subnet id"
  type        = string
}

variable "public_key" {
  description = "public key"
  type        = string
}