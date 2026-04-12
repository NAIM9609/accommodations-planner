output "app_url" {
  value = "https://${aws_amplify_branch.main.branch_name}.${aws_amplify_app.frontend.id}.amplifyapp.com"
}

output "app_id" {
  value = aws_amplify_app.frontend.id
}
