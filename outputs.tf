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

# ------------------------------------------------------------------ CloudFront
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (use as CLOUDFRONT_DISTRIBUTION_ID in CI)."
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name (the public app URL)."
  value       = aws_cloudfront_distribution.main.domain_name
}

output "app_url" {
  description = "Public HTTPS URL of the application."
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

# ------------------------------------------------------------------ WAF
output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL (null if WAF disabled)."
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : null
}
