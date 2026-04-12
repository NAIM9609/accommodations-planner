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

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrency per Lambda function to cap burst cost"
  type        = number
  default     = 2
  validation {
    condition     = var.lambda_reserved_concurrency >= 1 && var.lambda_reserved_concurrency <= 10
    error_message = "lambda_reserved_concurrency must be between 1 and 10 for low-cost workloads."
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

variable "amplify_github_token" {
  description = "GitHub personal access token for Amplify (stored in GitHub Actions secret AMPLIFY_GITHUB_TOKEN)"
  type        = string
  sensitive   = true
}
