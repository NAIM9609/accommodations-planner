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
  type = number
}
