variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (dev or prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod"
  }
}

variable "app_name" {
  description = "Application name used for resource naming"
  type        = string
  default     = "accommodations-planner"
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format for OIDC trust"
  type        = string
  default     = "NAIM9609/accommodations-planner"
}

variable "amplify_github_token" {
  description = "GitHub personal access token for Amplify (stored in GitHub secrets)"
  type        = string
  sensitive   = true
  default     = ""
}
