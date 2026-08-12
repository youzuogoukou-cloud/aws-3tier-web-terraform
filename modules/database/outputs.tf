output "rds_hostname" {
  description = "Hostname of the RDS instance.Pass to mysql -h; port is not included."
  value       = aws_db_instance.rds.address
}