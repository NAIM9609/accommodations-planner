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
  type = number
}

variable "throttle_burst_limit" {
  type = number
}
