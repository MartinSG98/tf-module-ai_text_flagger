# ------------------------------------------------------------------ Frontend
output "frontend_bucket" {
  description = "Name of the S3 bucket hosting the frontend (use as AWS_S3_BUCKET in CI)."
  value       = aws_s3_bucket.frontend.id
}

output "frontend_bucket_arn" {
  description = "ARN of the frontend S3 bucket."
  value       = aws_s3_bucket.frontend.arn
}

# ------------------------------------------------------------------ Backend
output "backend_instance_id" {
  description = "EC2 instance ID of the backend."
  value       = aws_instance.backend.id
}

output "backend_public_ip" {
  description = "Public IP of the backend (Elastic IP if enabled)."
  value       = local.backend_public_ip
}

output "backend_security_group_id" {
  description = "Security group ID protecting the backend."
  value       = aws_security_group.backend.id
}
