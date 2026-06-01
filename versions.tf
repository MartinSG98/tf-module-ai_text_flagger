terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0"

      # CloudFront WAF (and any future ACM certs) must live in us-east-1,
      # while the rest of the stack lives in the primary region. The root
      # stack passes both provider configurations in.
      configuration_aliases = [aws, aws.us_east_1]
    }
  }
}
