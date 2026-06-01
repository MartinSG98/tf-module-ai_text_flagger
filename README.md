# terraform-aws-ai-text-flagger

Reusable Terraform module that provisions the AI Text Flagger AWS architecture:

```
User → CloudFront (HTTPS + WAF) ─┬─ default (*)  → S3 (React frontend, private via OAC)
                                 ├─ /predict*     → EC2 (FastAPI backend, :8000)
                                 └─ /health       → EC2 (FastAPI backend, :8000)
```

This repo is the **module** only. It is meant to be tagged and consumed by a
separate deployment stack — see the `ai_text_flagger_tf_stack` repo. Do not
`apply` this directly.

## What it creates

| File          | Resources |
|---------------|-----------|
| `s3.tf`       | Private frontend bucket, OAC bucket policy, encryption, versioning |
| `ec2.tf`      | Ubuntu 24.04 backend, security group (22 + 8000), optional key pair + EIP, IMDSv2 |
| `cloudfront.tf` | Distribution (S3 default + EC2 `/predict*`, `/health`), OAC, spa-rewrite function |
| `waf.tf`      | CLOUDFRONT-scope WAFv2 Web ACL (Common Rule Set w/ overrides + rate limit) |
| `iam.tf`      | Scoped deploy policy + optional legacy access-key user |
| `iam_oidc.tf` | GitHub Actions OIDC provider + repo-scoped deploy role |

## Providers

CLOUDFRONT-scope WAF must live in `us-east-1`, so the module requires **two**
provider configurations. Pass both from the caller:

```hcl
module "ai_text_flagger" {
  source = "git::https://github.com/MartinSG98/tf-module-ai_text_flagger.git?ref=v1.0.0"

  providers = {
    aws           = aws            # primary region (eu-west-2)
    aws.us_east_1 = aws.us_east_1  # CloudFront WAF / ACM
  }

  frontend_bucket_name = "atf-frontend-ew2"
  github_repository     = "MartinSG98/ai_text_flagger_ui"
  # ...
}
```

## Key inputs

| Variable                      | Default          | Notes |
|-------------------------------|------------------|-------|
| `frontend_bucket_name`        | — (required)     | Globally unique S3 bucket name. |
| `enable_model_bucket`         | `true`           | Create a model S3 bucket; backend auto-pulls it on boot. |
| `model_bucket_name`           | `""`             | Globally unique S3 name; required when `enable_model_bucket`. |
| `model_s3_prefix`             | `model/final`    | Key prefix synced into `output/model/final`. |
| `region`                      | `eu-west-2`      | Primary region. |
| `instance_type`               | `m7i-flex.large` | Backend EC2 size. |
| `ssh_public_key`              | `""`             | Empty = no key pair (use SSM). |
| `ssh_ingress_cidrs`           | `[]`             | Lock SSH to your IP. |
| `enable_waf`                  | `true`           | Create + attach the Web ACL. |
| `create_github_oidc_role`     | `true`           | GitHub Actions OIDC deploy role. |
| `create_github_oidc_provider` | `true`           | Set `false` + `github_oidc_provider_arn` if one exists. |
| `github_repository`           | `""`             | `owner/repo` allowed to assume the role. |
| `create_cicd_user`            | `false`          | Legacy static-key user (prefer OIDC). |

See `variables.tf` for the full list.

## Key outputs

`app_url`, `cloudfront_distribution_id`, `frontend_bucket`, `model_bucket`,
`backend_public_ip`, `backend_instance_id`, `github_actions_role_arn`,
`github_oidc_provider_arn`, and (when the legacy user is enabled)
`cicd_access_key_id` / `cicd_secret_access_key`.

## Versioning

Consumers pin a git tag via `?ref=`. Release a change by tagging:

```bash
git tag v1.1.0 && git push --tags
```

Then bump `?ref=` in the consuming stack.

## Model delivery

The trained BERT model is too large for git. When `enable_model_bucket = true`
(default), the module creates a private S3 bucket and grants the backend instance
role read access; the EC2 user-data runs `aws s3 sync` from that bucket into
`output/model/final/` on boot, so a rebuilt/replaced instance self-provisions.

Upload the model to the bucket once:

```bash
aws s3 sync output/model/final/ "s3://$(terraform output -raw model_bucket)/model/final/"
```

Set `enable_model_bucket = false` to skip this and manage the model yourself
(e.g. manual `scp`).

## Notes

- The backend reaches the model via its IAM instance role (no keys), and supports
  SSM Session Manager, so SSH is optional.
- Uses the default VPC for a drop-in single-instance topology.
- HTTPS uses the default `*.cloudfront.net` cert unless `cloudfront_aliases` +
  `acm_certificate_arn` (us-east-1) are supplied.

## How this module was built

I scaffolded this module with Claude (Claude Code), then reviewed and adapted it.
The starting prompt, given alongside my project README, was roughly:

> Build me a reusable Terraform module that reproduces the AWS architecture in my
> AI Text Flagger README. It should provision:
>
> - An **S3** bucket for the React frontend, private, reachable only by CloudFront
>   via Origin Access Control.
> - An **EC2** instance (Ubuntu 24.04, m7i-flex.large, 20 GB gp3, eu-west-2)
>   running the FastAPI backend on port 8000 under a systemd service, bootstrapped
>   with user-data the same way I set it up by hand. Security group for SSH + 8000.
> - A **CloudFront** distribution with two origins: S3 as the default behavior, and
>   the EC2 backend for `/predict*` and `/health` (no caching, forward the
>   `x-api-key` header). Add the `spa-rewrite` function for React client-side routes.
> - A **WAFv2** Web ACL on CloudFront (must be in us-east-1) using the AWS Common
>   Rule Set, with `SizeRestrictions_BODY`, `CrossSiteScripting_BODY`,
>   `GenericLFI_BODY` and `GenericRFI_BODY` set to Count so large text and file
>   uploads work, plus a rate-based rule.
> - IAM for CI/CD: a **GitHub Actions OIDC** provider + a repo-scoped role (no
>   static keys), with a scoped S3 + CloudFront deploy policy.
>
> Make everything configurable through variables, keep it as a clean reusable
> module with sensible defaults, and output the values my deploy pipeline needs.
