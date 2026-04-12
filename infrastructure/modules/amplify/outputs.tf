output "app_url" {
  value = "https://${aws_amplify_branch.main.branch_name}.${aws_amplify_app.frontend.id}.amplifyapp.com"
}

output "app_id" {
  value = aws_amplify_app.frontend.id
}

output "custom_domain_url" {
  value = var.custom_domain_enabled ? (
    var.custom_domain_prefix != "" ? "https://${var.custom_domain_prefix}.${var.custom_domain_name}" : "https://${var.custom_domain_name}"
  ) : null
}
