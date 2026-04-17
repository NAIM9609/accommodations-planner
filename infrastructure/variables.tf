variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev or prod)"
  type        = string
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

variable "github_branch" {
  description = "GitHub branch Amplify should build from"
  type        = string
  default     = "master"
}

variable "amplify_custom_domain_enabled" {
  description = "Enable Amplify custom domain association"
  type        = bool
  default     = false
}

variable "amplify_custom_domain_name" {
  description = "Custom domain to attach to Amplify (for example: example.com)"
  type        = string
  default     = ""
  validation {
    condition = (
      length(trimspace(var.amplify_custom_domain_name)) == 0 ||
      can(regex("^([a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,}$", var.amplify_custom_domain_name))
    )
    error_message = "amplify_custom_domain_name must be empty or a valid DNS hostname (for example: app.example.com)."
  }
}

variable "amplify_custom_domain_prefix" {
  description = "Subdomain prefix for Amplify custom domain mapping (empty string for apex/root domain)"
  type        = string
  default     = ""
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrency per Lambda function. Use -1 for unreserved (default)."
  type        = number
  default     = -1
  validation {
    condition     = var.lambda_reserved_concurrency == -1 || var.lambda_reserved_concurrency >= 0
    error_message = "lambda_reserved_concurrency must be -1 (unreserved) or a non-negative number."
  }
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention for Lambda logs"
  type        = number
  default     = 3
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30], var.cloudwatch_log_retention_days)
    error_message = "cloudwatch_log_retention_days must be one of: 1, 3, 5, 7, 14, 30."
  }
}

variable "api_throttle_rate_limit" {
  description = "Steady-state API Gateway stage rate limit (requests/second)"
  type        = number
  default     = 5
}

variable "api_throttle_burst_limit" {
  description = "API Gateway stage burst limit"
  type        = number
  default     = 10
}

variable "cors_additional_allowed_origins" {
  description = "Additional exact origins allowed for CORS (for example: https://app.example.com)"
  type        = list(string)
  default     = []
}

variable "amplify_github_token" {
  description = "GitHub personal access token for Amplify (stored in GitHub Actions secret AMPLIFY_GITHUB_TOKEN)"
  type        = string
  sensitive   = true
}

variable "allow_dynamodb_destroy" {
  description = "Allow Terraform to destroy/replace DynamoDB table when explicitly intended."
  type        = bool
  default     = false
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. This provider is one-per-AWS-account and should be created exactly once from the dev bootstrap state/environment. For a fresh account bootstrap, run Terraform with -var=\"environment=dev\" -var=\"create_github_oidc_provider=true\". After that one-time creation, leave this as false (the default) so Terraform looks up the existing provider ARN with a data source instead of trying to recreate it from other states/environments."
  type        = bool
  default     = false
}
