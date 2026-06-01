# --------------------------------------------------------------------------
# WAFv2 Web ACL for CloudFront. CLOUDFRONT-scope ACLs MUST be created in
# us-east-1, hence the aws.us_east_1 provider alias.
#
# The AWS managed Common Rule Set is enabled, but the rules that interfere
# with large text inputs and file uploads are overridden to "Count" (per the
# backend README), plus a rate-based rule for basic DDoS protection.
# --------------------------------------------------------------------------

resource "aws_wafv2_web_acl" "main" {
  count    = var.enable_waf ? 1 : 0
  provider = aws.us_east_1

  name        = "${local.name_prefix}-cf-acl"
  description = "AI Text Flagger CloudFront protections"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # AWS Managed Common Rule Set, with uploads/large-body rules set to Count.
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }
        rule_action_override {
          name = "CrossSiteScripting_BODY"
          action_to_use {
            count {}
          }
        }
        rule_action_override {
          name = "GenericLFI_BODY"
          action_to_use {
            count {}
          }
        }
        rule_action_override {
          name = "GenericRFI_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # Known bad inputs.
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # Rate-based DDoS protection.
  rule {
    name     = "RateLimit"
    priority = 30

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-cf-acl"
    sampled_requests_enabled   = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cf-acl"
  })
}
