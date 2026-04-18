variable "prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "health_lambda_arn" {
  type = string
}

variable "health_lambda_name" {
  type = string
}

variable "reservations_lambda_arn" {
  type = string
}

variable "reservations_lambda_name" {
  type = string
}

variable "throttle_rate_limit" {
  description = "Steady-state API Gateway stage rate limit (requests/second)"
  type        = number
  default     = 5
}

variable "throttle_burst_limit" {
  description = "API Gateway stage burst limit"
  type        = number
  default     = 10
}
