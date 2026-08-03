resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project_name}_vpc" }
}

resource "aws_subnet" "private_subnet" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = "${var.region}${each.key}"
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.project_name}_subnet_${each.key}" }
}

resource "aws_route_table" "private_table" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.project_name}_route_table" }
}

resource "aws_route_table_association" "association" {
  for_each = var.subnets

  subnet_id      = aws_subnet.private_subnet[each.key].id
  route_table_id = aws_route_table.private_table.id
}

