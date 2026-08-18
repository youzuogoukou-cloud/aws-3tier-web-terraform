locals {
  common_tags = {
    ManagedBy = "Terraform"
    Project   = var.project_name
  }

  bucket_name     = "${var.project_name}-cloudtrail-${data.aws_caller_identity.my_account.account_id}-${var.region}"
  cloudtrail_name = "${var.project_name}_cloudtrail"
}