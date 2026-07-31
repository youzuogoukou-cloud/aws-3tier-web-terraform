terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project_name}_vpc" }
}

resource "aws_subnet" "public_subnet" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = "${var.region}${each.key}"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}_subnet_${each.key}" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}_gateway" }
}

resource "aws_route_table" "public_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = { Name = "${var.project_name}_route_table" }
}

resource "aws_route_table_association" "association" {
  for_each = var.subnets

  subnet_id      = aws_subnet.public_subnet[each.key].id
  route_table_id = aws_route_table.public_table.id
}



resource "aws_security_group" "ssh_sg" {
  name        = "ssh_sg"
  description = "Allow SSH from my IP"
  vpc_id      = aws_vpc.main.id

  ingress = []

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}_sg" }
}

resource "aws_key_pair" "key" {
  key_name   = "terraform-key"
  public_key = file("terraform-key.pub")
  tags       = { Name = "${var.project_name}_key_pair" }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_subnet["a"].id
  vpc_security_group_ids = [aws_security_group.ssh_sg.id]
  key_name               = aws_key_pair.key.key_name

  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  tags = { Name = "${var.project_name}_ec2" }
}

resource "aws_iam_role" "ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ec2_ssm_profile"
  role = aws_iam_role.ssm_role.name
}
