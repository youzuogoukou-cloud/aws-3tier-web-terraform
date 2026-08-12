output "alb_dns_name" {
  value = module.compute.alb_dns_name
}

output "rds_hostname" {
  description = "Hostname of the RDS instance.Pass to mysql -h; port is not included."
  value       = module.database.rds_hostname
}