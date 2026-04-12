output "api_url" {
  value = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${var.environment}"
}

output "rest_api_id" {
  value = aws_api_gateway_rest_api.api.id
}
