resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}_vpc" }
}

resource "aws_subnet" "public_subnet" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = "${var.region}${each.key}"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}_subnet_${each.key}" }
}

resource "aws_subnet" "private_subnet" {
  for_each = var.private_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = "${var.region}${each.key}"
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.project_name}_subnet_${each.key}" }
}

resource "aws_route_table" "public_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = { Name = "${var.project_name}_public_route_table" }
}

resource "aws_route_table" "private_table" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.project_name}_private_route_table" }
}

resource "aws_route_table_association" "public_association" {
  for_each = var.public_subnets

  subnet_id      = aws_subnet.public_subnet[each.key].id
  route_table_id = aws_route_table.public_table.id
}

resource "aws_route_table_association" "private_association" {
  for_each = var.private_subnets

  subnet_id      = aws_subnet.private_subnet[each.key].id
  route_table_id = aws_route_table.private_table.id
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.project_name}_internet_gateway" }
}

resource "aws_security_group" "endpoint_sg" {
  name        = "${var.project_name}_endpoint_sg"
  description = "Allow  inbound 443 from VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}_endpoint_sg" }
}

resource "aws_vpc_endpoint" "vpc_endpoint_ssm" {
  vpc_id = aws_vpc.main.id

  for_each            = toset(["ssm", "ec2messages", "ssmmessages"])
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for k, v in var.private_subnets : aws_subnet.private_subnet[k].id]
  security_group_ids  = [aws_security_group.endpoint_sg.id]
  private_dns_enabled = true
}


resource "aws_vpc_endpoint" "vpc_endpoint_s3" {
  vpc_id = aws_vpc.main.id

  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_table.id]
}

