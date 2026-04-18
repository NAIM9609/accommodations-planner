variable "prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "dynamodb_table_arn" {
  type = string
}

variable "dynamodb_table_name" {
  type = string
}

variable "amplify_branch" {
  description = "Amplify branch used to build frontend (used for dynamic CORS allowlist pattern)"
  type        = string
}

variable "custom_domain_url" {
  description = "Amplify custom domain URL to include in CORS allowlist"
  type        = string
  default     = ""
}

variable "cors_allowed_origins" {
  description = "Additional exact origins allowed for CORS"
  type        = list(string)
  default     = []
}

variable "reserved_concurrency" {
  description = "Reserved concurrency for Lambda functions. Use -1 for unreserved (default)."
  type        = number
  default     = -1

  validation {
    condition     = var.reserved_concurrency == -1 || var.reserved_concurrency >= 0
    error_message = "reserved_concurrency must be -1 (unreserved) or a non-negative number."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention for Lambda logs"
  type        = number
  default     = 3

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30], var.log_retention_days)
    error_message = "log_retention_days must be one of: 1, 3, 5, 7, 14, 30."
  }
}
