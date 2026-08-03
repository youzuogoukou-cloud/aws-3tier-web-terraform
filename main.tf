terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "tf-portfolio-state-533266981533-ap-northeast-1-an"
    key    = "terraform.tfstate"
    region = "ap-northeast-1"
    use_lockfile = true
    encrypt      = true
}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

moved {
  from = aws_vpc.main
  to   = module.network.aws_vpc.main
}

moved {
  from = aws_subnet.public_subnet
  to   = module.network.aws_subnet.public_subnet
}

moved {
  from = aws_internet_gateway.gw
  to   = module.network.aws_internet_gateway.gw
}

moved {
  from = aws_route_table.public_table
  to   = module.network.aws_route_table.public_table
}

moved {
  from = aws_route_table_association.association
  to   = module.network.aws_route_table_association.association
}

moved {
  from = aws_security_group.ssh_sg
  to   = module.compute.aws_security_group.ssm_sg
}

moved {
  from = aws_instance.ec2
  to   = module.compute.aws_instance.ec2
}

moved {
  from = aws_iam_role.ssm_role
  to   = module.compute.aws_iam_role.ssm_role
}

moved {
  from = aws_iam_role_policy_attachment.ssm
  to   = module.compute.aws_iam_role_policy_attachment.ssm
}

moved {
  from = aws_iam_instance_profile.ssm_profile
  to   = module.compute.aws_iam_instance_profile.ssm_profile
}

module "network" {
  source = "./modules/network/"

  region         = var.region
  subnets        = var.subnets
  vpc_cidr_block = var.vpc_cidr_block
  project_name   = var.project_name
}

module "compute" {
  source = "./modules/compute/"

  instance_type  = var.instance_type
  project_name   = var.project_name
  vpc_id         = module.network.vpc_id
  subnet_id      = module.network.subnet_ids["a"]
}

