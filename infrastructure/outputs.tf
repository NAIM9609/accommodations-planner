output "api_url" {
  description = "API Gateway base URL"
  value       = module.api_gateway.api_url
}

output "frontend_url" {
  description = "Amplify app default domain"
  value       = module.amplify.app_url
}

output "amplify_app_id" {
  description = "Amplify app ID for triggering builds"
  value       = module.amplify.app_id
}

output "frontend_custom_domain_url" {
  description = "Amplify custom domain URL when enabled"
  value       = module.amplify.custom_domain_url
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = module.dynamodb.table_name
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC"
  value       = aws_iam_role.github_actions.arn
}
