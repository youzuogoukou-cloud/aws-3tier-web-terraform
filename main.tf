terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket       = "tf-portfolio-state-533266981533-ap-northeast-1-an"
    key          = "terraform.tfstate"
    region       = "ap-northeast-1"
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

  region         = var.region
  subnets        = var.subnets
  vpc_cidr_block = var.vpc_cidr_block
  project_name   = var.project_name
}

module "compute" {
  source = "./modules/compute/"

  instance_type = var.instance_type
  project_name  = var.project_name
  vpc_id        = module.network.vpc_id
  subnet_id     = module.network.subnet_ids["a"]
}

