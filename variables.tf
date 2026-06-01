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
