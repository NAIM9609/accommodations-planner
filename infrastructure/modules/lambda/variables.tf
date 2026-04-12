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
  type = number
}

variable "log_retention_days" {
  type = number
}
