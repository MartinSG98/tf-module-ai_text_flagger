# ------------------------------------------------------------------ Frontend
output "frontend_bucket" {
  description = "Name of the S3 bucket hosting the frontend (use as AWS_S3_BUCKET in CI)."
  value       = aws_s3_bucket.frontend.id
}

output "frontend_bucket_arn" {
  description = "ARN of the frontend S3 bucket."
  value       = aws_s3_bucket.frontend.arn
}
