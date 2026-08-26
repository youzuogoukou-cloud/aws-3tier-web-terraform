terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
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

module "network" {
  source = "./modules/network/"

  region          = var.region
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  vpc_cidr_block  = var.vpc_cidr_block
  project_name    = var.project_name
}

module "compute" {
  source = "./modules/compute/"

  instance_type      = var.instance_type
  project_name       = var.project_name
  vpc_id             = module.network.vpc_id
  vpc_cidr_block     = var.vpc_cidr_block
  public_subnet_ids  = values(module.network.public_subnet_ids)
  private_subnet_ids = values(module.network.private_subnet_ids)
  ec2_accesslog_name = module.logging.ec2_accesslog_name
  ec2_accesslog_arn  = module.logging.ec2_accesslog_arn
  ec2_errorlog_name  = module.logging.ec2_errorlog_name
  ec2_errorlog_arn   = module.logging.ec2_errorlog_arn
  s3_prefix_list_id  = module.network.s3_prefix_list_id
}

module "database" {
  source = "./modules/database/"

  project_name       = var.project_name
  vpc_id             = module.network.vpc_id
  private_subnet_ids = values(module.network.private_subnet_ids)
  ec2_sg_id          = module.compute.ec2_sg_id
}

module "logging" {
  source = "./modules/logging/"

  project_name = var.project_name
}

