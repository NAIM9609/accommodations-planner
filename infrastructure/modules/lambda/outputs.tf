output "health_lambda_arn" {
  value = aws_lambda_function.health.arn
}

output "health_lambda_name" {
  value = aws_lambda_function.health.function_name
}

output "reservations_lambda_arn" {
  value = aws_lambda_function.reservations.arn
}

output "reservations_lambda_name" {
  value = aws_lambda_function.reservations.function_name
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}
