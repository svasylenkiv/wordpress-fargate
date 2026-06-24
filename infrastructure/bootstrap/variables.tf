variable "aws_region" {
  description = "AWS region for bootstrap resources"
  type        = string
  # Sandbox SCP часто дозволяє лише us-east-1; для prod можна eu-central-1
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name — used as prefix for all resource names"
  type        = string
  default     = "wordpress-fargate"
}

variable "github_org" {
  description = "GitHub organization or username (for OIDC trust policy)"
  type        = string
  # default   = "your-github-username"
}

variable "github_repo" {
  description = "GitHub repository name (for OIDC trust policy)"
  type        = string
  default     = "wordpress-fargate"
}