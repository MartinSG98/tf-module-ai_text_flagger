# --------------------------------------------------------------------------
# GitHub Actions OIDC: lets the deploy workflow assume an IAM role via a
# short-lived web-identity token instead of static access keys.
#
#   GitHub Actions ──(OIDC token)──> sts:AssumeRoleWithWebIdentity ──> role
#
# The role trusts only the configured repository (and subject patterns, e.g.
# a specific branch/environment).
# --------------------------------------------------------------------------

locals {
  # ARN of the OIDC provider to trust: the one we create, or a pre-existing one.
  github_oidc_provider_arn = var.create_github_oidc_role ? (
    var.create_github_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
    : var.github_oidc_provider_arn
  ) : null

  # Default subject: pushes to the main branch of the configured repo.
  github_oidc_subjects = length(var.github_oidc_subjects) > 0 ? var.github_oidc_subjects : [
    "repo:${var.github_repository}:ref:refs/heads/main",
  ]
}

# An account can only have ONE provider per URL — set create_github_oidc_provider
# = false and pass github_oidc_provider_arn if you already have one.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_role && var.create_github_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.github_oidc_thumbprints

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-github-oidc"
  })
}

data "aws_iam_policy_document" "github_assume" {
  count = var.create_github_oidc_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_oidc_subjects
    }
  }
}

resource "aws_iam_role" "github_actions" {
  count = var.create_github_oidc_role ? 1 : 0

  name               = "${local.name_prefix}-github-actions"
  description        = "Assumed by GitHub Actions via OIDC to deploy the frontend"
  assume_role_policy = data.aws_iam_policy_document.github_assume[0].json

  tags = local.common_tags

  lifecycle {
    precondition {
      condition     = var.github_repository != "" || length(var.github_oidc_subjects) > 0
      error_message = "Set github_repository (\"owner/repo\") or github_oidc_subjects when create_github_oidc_role is true."
    }
  }
}

resource "aws_iam_role_policy" "github_actions" {
  count = var.create_github_oidc_role ? 1 : 0

  name   = "${local.name_prefix}-github-actions-deploy"
  role   = aws_iam_role.github_actions[0].id
  policy = data.aws_iam_policy_document.deploy.json
}
