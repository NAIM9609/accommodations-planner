variable "table_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "allow_table_destroy" {
  description = "Allow Terraform to destroy/replace the DynamoDB table when explicitly required."
  type        = bool
  default     = false
}
