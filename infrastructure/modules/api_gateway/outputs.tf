output "api_url" {
  value = aws_apigatewayv2_stage.api.invoke_url
}

output "api_id" {
  value = aws_apigatewayv2_api.api.id
}
