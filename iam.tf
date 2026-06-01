# --------------------------------------------------------------------------
# Deployment permissions for CI/CD (frontend build -> S3 sync -> CloudFront
# invalidation). The same scoped policy is attached to whichever identity is
# enabled: the GitHub OIDC role (preferred, see iam_oidc.tf) and/or a legacy
# access-key user.
# --------------------------------------------------------------------------

data "aws_iam_policy_document" "deploy" {
  statement {
    sid    = "S3FrontendSync"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      aws_s3_bucket.frontend.arn,
      "${aws_s3_bucket.frontend.arn}/*",
    ]
  }

  statement {
    sid    = "CloudFrontInvalidate"
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
      "cloudfront:ListInvalidations",
      "cloudfront:GetDistribution",
    ]
    resources = [aws_cloudfront_distribution.main.arn]
  }
}

# --------------------------------------------------------------------------
# Optional legacy IAM user with static access keys. Disabled by default in
# favour of the OIDC role; enable only if a workflow can't use OIDC.
# --------------------------------------------------------------------------

resource "aws_iam_user" "cicd" {
  count = var.create_cicd_user ? 1 : 0

  name = var.cicd_user_name
  tags = local.common_tags
}

resource "aws_iam_user_policy" "cicd" {
  count = var.create_cicd_user ? 1 : 0

  name   = "${var.cicd_user_name}-deploy"
  user   = aws_iam_user.cicd[0].name
  policy = data.aws_iam_policy_document.deploy.json
}

resource "aws_iam_access_key" "cicd" {
  count = var.create_cicd_user ? 1 : 0

  user = aws_iam_user.cicd[0].name
}
