# tf-module-ai_text_flagger

Terraform module that builds the AWS side of AI Text Flagger, a fine-tuned BERT classifier that tells human-written text from AI-generated text. It creates a private S3 bucket for the React frontend, a private S3 bucket for the trained model, an EC2 instance that runs the FastAPI backend, a CloudFront distribution in front of both, a WAF web ACL, and the IAM for the instance and for GitHub Actions deploys. It reproduces the setup that was first done by hand in the AWS console.

This repo is the module only and is not applied directly. [tf-stack-ai_text_flagger](https://github.com/MartinSG98/tf-stack-ai_text_flagger) pins a tagged version of it and is what you apply. The application lives in [ai_text_flagger](https://github.com/MartinSG98/ai_text_flagger) (the model and the API) and [ai_text_flagger_ui](https://github.com/MartinSG98/ai_text_flagger_ui) (the frontend).

```
User → CloudFront (HTTPS, WAF) ─┬─ default (*) → S3 frontend bucket (private, via OAC)
                                ├─ /predict*   → EC2 backend, FastAPI on :8000 (HTTP)
                                └─ /health     → EC2 backend, FastAPI on :8000 (HTTP)

EC2 instance role   → S3 model bucket (read, on first boot)
GitHub Actions OIDC → deploy role → S3 frontend sync + CloudFront invalidation
```

## What it creates

| File | Resources |
|---|---|
| `s3.tf` | Frontend bucket with public access blocked, bucket-owner-enforced ownership, versioning, AES256 encryption and a policy that lets only this distribution read objects. An optional model bucket with the same settings and no bucket policy |
| `ec2.tf` | Latest Canonical Ubuntu 24.04 AMI (x86_64), a security group in the default VPC, an optional key pair, the instance (IMDSv2 only, encrypted root volume, user data from `templates/user_data.sh.tftpl`) and an optional Elastic IP |
| `iam_ec2.tf` | Instance role and profile with `AmazonSSMManagedInstanceCore` for Session Manager, plus read access to the model bucket when it exists |
| `cloudfront.tf` | Origin Access Control, the `spa-rewrite` CloudFront Function from `functions/spa-rewrite.js`, and the distribution with two origins and three behaviors |
| `waf.tf` | CLOUDFRONT-scope WAFv2 web ACL, created in us-east-1 |
| `iam.tf` | The deploy policy and an optional legacy IAM user with an access key |
| `iam_oidc.tf` | GitHub Actions OIDC provider (optional) and the role it assumes |
| `main.tf` | Name prefix (`<project>-<environment>`) and the tags every resource gets |

The security group allows SSH from `ssh_ingress_cidrs`, the API port from `api_ingress_cidrs` and all outbound traffic.

CloudFront behaviors:

| Path | Origin | Viewer protocol | Methods | Cache policy | Origin request policy |
|---|---|---|---|---|---|
| default (`*`) | S3 through OAC | Redirect to HTTPS | GET, HEAD, OPTIONS | CachingOptimized | none, `spa-rewrite` on viewer request |
| `/predict*` | EC2 over HTTP on `api_port` | HTTPS only | All seven | CachingDisabled | AllViewer, so `x-api-key` reaches the API |
| `/health` | EC2 over HTTP on `api_port` | HTTPS only | GET, HEAD, OPTIONS | CachingDisabled | AllViewer |

The `spa-rewrite` function sends every path without a file extension to `/index.html`.

WAF rules:

| Priority | Rule | Action |
|---|---|---|
| 10 | AWS Common Rule Set | The group's own actions, with `SizeRestrictions_BODY`, `CrossSiteScripting_BODY`, `GenericLFI_BODY` and `GenericRFI_BODY` set to Count |
| 20 | AWS Known Bad Inputs Rule Set | The group's own actions |
| 30 | `RateLimit` | Blocks an IP past `waf_rate_limit` requests in five minutes |

The four Common Rule Set overrides are there because long texts and file uploads tripped them. Every rule sends metrics to CloudWatch and keeps sampled requests.

The deploy policy allows `s3:ListBucket`, `GetObject`, `PutObject` and `DeleteObject` on the frontend bucket and `cloudfront:CreateInvalidation`, `GetInvalidation`, `ListInvalidations` and `GetDistribution` on the distribution. It is attached to the OIDC role and to the legacy user, whichever exist.

The instance's user data does what the manual setup did:

1. **Packages.** Updates Ubuntu and installs `python3-pip`, `python3-venv` and `git`.
2. **Code.** Clones `backend_repo_url` to `/home/ubuntu/ai_text_flagger` and creates a venv there.
3. **Python.** Installs CPU-only PyTorch, then FastAPI, uvicorn, transformers, python-dotenv, python-docx, pypdf, accelerate, datasets, safetensors, huggingface-hub and python-multipart.
4. **Model.** When there is a model bucket, installs the AWS CLI from snap and syncs `s3://<model bucket>/<model_s3_prefix>/` into `output/model/final/`.
5. **Service.** Writes a systemd unit called `atf` that runs `uvicorn src.api:app --host 0.0.0.0 --port <api_port>` as `ubuntu`, reads `/home/ubuntu/ai_text_flagger/.env` if it exists and restarts on failure, then enables and starts it.

## Providers

Requires Terraform 1.5.0 or newer and the `hashicorp/aws` provider 5.40.0 or newer. A CLOUDFRONT-scope web ACL has to live in us-east-1 while everything else lives in the primary region, so the module declares two provider configurations, `aws` and `aws.us_east_1`, and the caller passes both. An ACM certificate for custom domains has to be in us-east-1 too.

## Usage

```hcl
provider "aws" {
  region = "eu-west-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

module "ai_text_flagger" {
  source = "git::https://github.com/MartinSG98/tf-module-ai_text_flagger.git?ref=v1.1.0"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  frontend_bucket_name = "<globally-unique-frontend-bucket>"
  model_bucket_name    = "<globally-unique-model-bucket>"
  github_repository    = "MartinSG98/ai_text_flagger_ui"
}
```

There are two tags. `v1.0.0` is the first release and `v1.1.0` adds the model bucket and the S3 pull on boot. To release a change, tag it and bump `?ref=` in the stack:

```bash
git tag v1.2.0
git push origin v1.2.0
```

## Inputs

| Variable | Type | Default | Purpose |
|---|---|---|---|
| `project` | string | `"atf"` | First part of resource names and the `Project` tag |
| `environment` | string | `"prod"` | Second part of resource names and the `Environment` tag |
| `region` | string | `"eu-west-2"` | Region the user data passes to `aws s3 sync` for the model bucket. The resources go wherever the `aws` provider points |
| `tags` | map(string) | `{}` | Extra tags merged onto every resource |
| `frontend_bucket_name` | string | required | Globally unique name of the frontend bucket |
| `enable_model_bucket` | bool | `true` | Create the model bucket and have the instance pull the model from it on boot |
| `model_bucket_name` | string | `""` | Globally unique name of the model bucket. Required when `enable_model_bucket` is true |
| `model_s3_prefix` | string | `"model/final"` | Key prefix in the model bucket that is synced into `output/model/final` |
| `instance_type` | string | `"m7i-flex.large"` | Backend instance type |
| `root_volume_size` | number | `20` | Root volume size in GiB |
| `root_volume_type` | string | `"gp3"` | Root volume type |
| `ssh_public_key` | string | `""` | Public key for an EC2 key pair. Empty creates no key pair, and Session Manager is the way in |
| `ssh_ingress_cidrs` | list(string) | `[]` | CIDR blocks allowed on port 22. Empty opens no SSH at all |
| `api_ingress_cidrs` | list(string) | `["0.0.0.0/0"]` | CIDR blocks allowed on the API port |
| `api_port` | number | `8000` | Port uvicorn listens on and CloudFront connects to |
| `backend_repo_url` | string | `"https://github.com/MartinSG98/ai_text_flagger.git"` | Repo the user data clones |
| `assign_elastic_ip` | bool | `true` | Attach an Elastic IP, so the CloudFront origin keeps its address when the instance stops |
| `cloudfront_price_class` | string | `"PriceClass_100"` | CloudFront price class |
| `cloudfront_aliases` | list(string) | `[]` | Custom domain names for the distribution. Needs `acm_certificate_arn` |
| `acm_certificate_arn` | string | `""` | ACM certificate in us-east-1 for the aliases. Empty uses the default `*.cloudfront.net` certificate |
| `enable_waf` | bool | `true` | Create the web ACL and attach it to the distribution |
| `waf_rate_limit` | number | `2000` | Requests per IP in a five-minute window before the rate rule blocks |
| `create_github_oidc_role` | bool | `true` | Create the role GitHub Actions assumes through OIDC |
| `create_github_oidc_provider` | bool | `true` | Create the GitHub OIDC provider. An account can only have one, so set this to false and pass `github_oidc_provider_arn` if it already exists |
| `github_oidc_provider_arn` | string | `""` | ARN of an existing provider, used when `create_github_oidc_provider` is false |
| `github_repository` | string | `""` | `owner/repo` allowed to assume the role, for example `MartinSG98/ai_text_flagger_ui` |
| `github_oidc_subjects` | list(string) | `[]` | Subject patterns that replace the default, which is the main branch of `github_repository` |
| `github_oidc_thumbprints` | list(string) | GitHub's two published thumbprints | Thumbprints for the provider. IAM no longer checks them for GitHub, but the resource needs a value |
| `create_cicd_user` | bool | `false` | Create the legacy IAM user with a static access key |
| `cicd_user_name` | string | `"atf-github-actions"` | Name of that user |

With `create_github_oidc_role` on, a precondition fails the plan unless `github_repository` or `github_oidc_subjects` is set. With `enable_model_bucket` on, another one fails it unless `model_bucket_name` is set.

## Outputs

| Output | What it is |
|---|---|
| `frontend_bucket` | Name of the frontend bucket, the UI workflow's `AWS_S3_BUCKET` |
| `frontend_bucket_arn` | ARN of the frontend bucket |
| `model_bucket` | Name of the model bucket, null when it is disabled |
| `backend_instance_id` | ID of the backend instance |
| `backend_public_ip` | The Elastic IP when there is one, otherwise the instance's public IP |
| `backend_security_group_id` | ID of the backend's security group |
| `cloudfront_distribution_id` | ID of the distribution, the UI workflow's `CLOUDFRONT_DISTRIBUTION_ID` |
| `cloudfront_domain_name` | The distribution's `*.cloudfront.net` domain |
| `app_url` | `https://` plus that domain, the public URL of the app |
| `waf_web_acl_arn` | ARN of the web ACL, null when WAF is disabled |
| `github_actions_role_arn` | ARN of the deploy role for `role-to-assume`, null when the role is disabled |
| `github_oidc_provider_arn` | ARN of the OIDC provider the role trusts, created or passed in, null when the role is disabled |
| `cicd_access_key_id` | Access key ID of the legacy user, null unless it is enabled |
| `cicd_secret_access_key` | Its secret key, marked sensitive |

## Deployment notes

- **The model.** It is about 1.3 GB, too large for git, so it lives in the model bucket. Upload it once from the backend repo with `aws s3 sync output/model/final/ "s3://<model bucket>/model/final/"`. User data only runs on the first boot, so a model uploaded after that has to be synced on the instance by hand, through Session Manager, or picked up by replacing the instance. Set `enable_model_bucket = false` to manage the model yourself.
- **The API key.** The user data does not write `/home/ubuntu/ai_text_flagger/.env`. Until it holds `API_KEY=...` and `atf` is restarted, the predict routes answer 500.
- **Replacing the instance.** `user_data_replace_on_change` is on, so any change to the user data or its inputs replaces the instance. The root volume goes with it, and so does the `.env` file.
- **Access.** The instance role includes Session Manager, so SSH is optional. The backend repo's own deploy workflow connects over SSH, though, so it needs `ssh_public_key` and port 22 open to where it connects from.
- **The API port.** By default port 8000 is open to `0.0.0.0/0`, because CloudFront reaches the instance over plain HTTP on its public address. HTTPS ends at CloudFront.
- **Network.** The instance goes into the default VPC, which keeps the module drop-in for a single-instance setup.
- **Tearing down.** Neither bucket sets `force_destroy`, and both are versioned, so empty them (every version) before `terraform destroy`.
- **State.** With the legacy user on, its secret key is stored in the Terraform state. Keep the state private.
