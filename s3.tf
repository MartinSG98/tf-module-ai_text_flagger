# --------------------------------------------------------------------------
# S3 bucket hosting the static React frontend (dist/ contents).
# Public access is fully blocked; CloudFront reaches it via Origin Access
# Control (OAC) only.
# --------------------------------------------------------------------------

resource "aws_s3_bucket" "frontend" {
  bucket = var.frontend_bucket_name

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-frontend"
  })
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bucket policy: allow CloudFront (this distribution only) to read objects.
data "aws_iam_policy_document" "frontend" {
  statement {
    sid     = "AllowCloudFrontServicePrincipalReadOnly"
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend.json
}

# --------------------------------------------------------------------------
# S3 bucket holding the trained BERT model artifacts. The model is too large
# for git, so it lives here; the EC2 backend pulls it on boot via its instance
# role (see ec2.tf). Private — accessed by IAM, not a bucket policy.
# --------------------------------------------------------------------------

resource "aws_s3_bucket" "model" {
  count = var.enable_model_bucket ? 1 : 0

  bucket = var.model_bucket_name

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-model"
  })

  lifecycle {
    precondition {
      condition     = var.model_bucket_name != ""
      error_message = "Set model_bucket_name when enable_model_bucket is true."
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "model" {
  count = var.enable_model_bucket ? 1 : 0

  bucket = aws_s3_bucket.model[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "model" {
  count = var.enable_model_bucket ? 1 : 0

  bucket = aws_s3_bucket.model[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "model" {
  count = var.enable_model_bucket ? 1 : 0

  bucket = aws_s3_bucket.model[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "model" {
  count = var.enable_model_bucket ? 1 : 0

  bucket = aws_s3_bucket.model[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
