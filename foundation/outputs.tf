output "cloudtrail_bucket_name" {
  description = "CloudTrail bucket name to research the CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail_bucket.id
}