variable "prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "github_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "api_base_url" {
  type = string
}
