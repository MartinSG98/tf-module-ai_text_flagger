variable "project" {
  description = "Project name, used as a prefix for resource names and tags."
  type        = string
  default     = "atf"
}

variable "environment" {
  description = "Deployment environment (e.g. prod, staging). Used in tags and names."
  type        = string
  default     = "prod"
}

variable "region" {
  description = "Primary AWS region for the backend (EC2) and frontend bucket (S3)."
  type        = string
  default     = "eu-west-2"
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------ Frontend / S3
variable "frontend_bucket_name" {
  description = "Globally unique S3 bucket name for the static frontend (e.g. atf-frontend-ew2)."
  type        = string
}

# ------------------------------------------------------------------ Backend / EC2
variable "instance_type" {
  description = "EC2 instance type for the FastAPI backend."
  type        = string
  default     = "m7i-flex.large"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Root EBS volume type."
  type        = string
  default     = "gp3"
}

variable "ssh_public_key" {
  description = "SSH public key material for the EC2 key pair. Leave empty to skip key pair creation (use SSM instead)."
  type        = string
  default     = ""
}

variable "ssh_ingress_cidrs" {
  description = "CIDR blocks allowed to reach SSH (port 22). Default is locked down; set to your IP."
  type        = list(string)
  default     = []
}

variable "api_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the backend API (port 8000). Defaults to AWS CloudFront managed prefix list via security group; override only if needed."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "api_port" {
  description = "Port the FastAPI/uvicorn backend listens on."
  type        = number
  default     = 8000
}

variable "backend_repo_url" {
  description = "Git URL of the backend repo cloned by EC2 user-data."
  type        = string
  default     = "https://github.com/MartinSG98/ai_text_flagger.git"
}

variable "assign_elastic_ip" {
  description = "Whether to allocate and attach an Elastic IP to the backend instance (stable address for CloudFront origin)."
  type        = bool
  default     = true
}

# ------------------------------------------------------------------ CloudFront
variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_100, PriceClass_200, PriceClass_All)."
  type        = string
  default     = "PriceClass_100"
}

variable "cloudfront_aliases" {
  description = "Optional custom domain names (CNAMEs) for the distribution. Requires acm_certificate_arn."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ARN of an ACM certificate in us-east-1 for cloudfront_aliases. Empty uses the default *.cloudfront.net certificate."
  type        = string
  default     = ""
}

# ------------------------------------------------------------------ WAF
variable "enable_waf" {
  description = "Whether to create and attach a WAFv2 Web ACL to the distribution."
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "Requests per 5-minute window per IP before the rate-based rule blocks (DDoS protection)."
  type        = number
  default     = 2000
}

# ------------------------------------------------------------------ CI/CD: GitHub OIDC role
variable "create_github_oidc_role" {
  description = "Create an IAM role assumed by GitHub Actions via OIDC (preferred over static keys)."
  type        = bool
  default     = true
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set false (and pass github_oidc_provider_arn) if the account already has one."
  type        = bool
  default     = true
}

variable "github_oidc_provider_arn" {
  description = "ARN of an existing GitHub Actions OIDC provider, used when create_github_oidc_provider is false."
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the role, as \"owner/repo\" (e.g. MartinSG98/ai_text_flagger_ui)."
  type        = string
  default     = ""
}

variable "github_oidc_subjects" {
  description = "Explicit OIDC subject patterns allowed to assume the role. Overrides the default (main branch of github_repository)."
  type        = list(string)
  default     = []
}

variable "github_oidc_thumbprints" {
  description = "TLS thumbprints for the GitHub OIDC provider. IAM no longer enforces these for this provider, but the resource requires a value."
  type        = list(string)
  default = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# ------------------------------------------------------------------ CI/CD: legacy access-key user
variable "create_cicd_user" {
  description = "Create a legacy IAM user with static access keys for CI/CD. Off by default; prefer the OIDC role."
  type        = bool
  default     = false
}

variable "cicd_user_name" {
  description = "Name of the legacy IAM user used by GitHub Actions."
  type        = string
  default     = "atf-github-actions"
}
