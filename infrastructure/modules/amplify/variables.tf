variable "prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "github_branch" {
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

variable "custom_domain_enabled" {
  type    = bool
  default = false
}

variable "custom_domain_name" {
  type    = string
  default = ""
}

variable "custom_domain_prefix" {
  type    = string
  default = ""
}
