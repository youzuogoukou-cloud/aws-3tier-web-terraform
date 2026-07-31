locals {
  common_tags = {
    ManagedBy = "Terraform"
    Owner     = "infra-team"
    Project   = var.project_name
  }
}