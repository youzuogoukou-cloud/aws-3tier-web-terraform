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
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_iam_openid_connect_provider" "github_connect" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "cicd_apply_role" {
  name = "${var.project_name}_cicd_apply_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github_connect.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:youzuogoukou-cloud@293054394/aws-3tier-web-terraform@1332749804:environment:production"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "cicd_plan_role" {
  name = "${var.project_name}_cicd_plan_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github_connect.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:youzuogoukou-cloud@293054394/aws-3tier-web-terraform@1332749804:pull_request"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2" {
  role       = aws_iam_role.cicd_apply_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "rds" {
  role       = aws_iam_role.cicd_apply_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}

resource "aws_iam_role_policy_attachment" "iam" {
  role       = aws_iam_role.cicd_apply_role.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.cicd_apply_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy_attachment" "read_only" {
  role       = aws_iam_role.cicd_plan_role.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "cicd_apply_policy" {
  name = "${var.project_name}_cicd_apply_policy"
  role = aws_iam_role.cicd_apply_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "TerraformACMImport",
        "Effect" : "Allow",
        "Action" : [
          "acm:ImportCertificate",
          "acm:DescribeCertificate",
          "acm:ListTagsForCertificate",
          "acm:AddTagsToCertificate",
          "acm:RemoveTagsFromCertificate",
          "acm:DeleteCertificate"
        ],
        "Resource" : "arn:aws:acm:ap-northeast-1:533266981533:certificate/*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "kms:ListAliases",
          "kms:DescribeKey"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "kms:CreateGrant",
          "kms:GenerateDataKey"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "kms:ViaService" : "rds.ap-northeast-1.amazonaws.com"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:CreateSecret",
          "secretsmanager:TagResource",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:RotateSecret",
          "secretsmanager:DeleteSecret"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : "s3:ListBucket",
        "Resource" : "arn:aws:s3:::tf-portfolio-state-533266981533-ap-northeast-1-an"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        "Resource" : "arn:aws:s3:::tf-portfolio-state-533266981533-ap-northeast-1-an/*"
      }

    ]
  })
}

resource "aws_iam_role_policy" "cicd_plan_policy" {
  name = "${var.project_name}_cicd_plan_policy"
  role = aws_iam_role.cicd_plan_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject"] # ロック用の書き込みだけ
        Resource = "arn:aws:s3:::tf-portfolio-state-533266981533-ap-northeast-1-an/*"
      }
    ]
  })
}
