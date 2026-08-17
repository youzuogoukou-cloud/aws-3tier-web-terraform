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

data "aws_caller_identity" "my_account" {}

resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket = local.bucket_name

  tags = { Name = local.bucket_name }
}