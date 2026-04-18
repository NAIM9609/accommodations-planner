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
  description = "Custom domain to attach to Amplify (for example: example.com)"
  type        = string
  default     = ""

  validation {
    condition = (
      length(trimspace(var.custom_domain_name)) == 0 ||
      can(regex("^([a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,}$", var.custom_domain_name))
    )
    error_message = "custom_domain_name must be empty or a valid DNS hostname (for example: app.example.com)."
  }
}

variable "custom_domain_prefix" {
  description = "Subdomain prefix for Amplify custom domain mapping (empty string for apex/root domain)"
  type        = string
  default     = ""
}
