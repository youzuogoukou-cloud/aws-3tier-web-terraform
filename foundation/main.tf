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

resource "aws_s3_bucket_policy" "allow_access_from_another_service" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AWSCloudTrailAclCheck20150319",
        "Effect" : "Allow",
        "Principal" : { "Service" : "cloudtrail.amazonaws.com" },
        "Action" : "s3:GetBucketAcl",
        "Resource" : aws_s3_bucket.cloudtrail_bucket.arn,
        "Condition" : {
          "StringEquals" : {
            "aws:SourceArn" : "arn:aws:cloudtrail:${var.region}:${data.aws_caller_identity.my_account.account_id}:trail/${local.cloudtrail_name}"
          }
        }
      },
      {
        "Sid" : "AWSCloudTrailWrite20150319",
        "Effect" : "Allow",
        "Principal" : { "Service" : "cloudtrail.amazonaws.com" },
        "Action" : "s3:PutObject",
        "Resource" : "${aws_s3_bucket.cloudtrail_bucket.arn}/AWSLogs/${data.aws_caller_identity.my_account.account_id}/*",
        "Condition" : {
          "StringEquals" : {
            "s3:x-amz-acl" : "bucket-owner-full-control",
            "aws:SourceArn" : "arn:aws:cloudtrail:${var.region}:${data.aws_caller_identity.my_account.account_id}:trail/${local.cloudtrail_name}"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "cloudtrail" {
  name                          = local.cloudtrail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  depends_on                    = [aws_s3_bucket_policy.allow_access_from_another_service]
}

resource "aws_s3_bucket_public_access_block" "public_access_block_cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "versioning_cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle_cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  rule {
    filter {}
    id = "expire-cloudtrail-logs"
    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    expiration {
      days = 365
    }
    status = "Enabled"
  }
}