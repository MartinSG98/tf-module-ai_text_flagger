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
