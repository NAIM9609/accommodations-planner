data "aws_region" "current" {}

resource "aws_apigatewayv2_api" "api" {
  name          = "${var.prefix}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "health" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  payload_format_version = "1.0"
  integration_uri        = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.health_lambda_arn}/invocations"
}

resource "aws_apigatewayv2_integration" "reservations" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  payload_format_version = "1.0"
  integration_uri        = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.reservations_lambda_arn}/invocations"
}

resource "aws_apigatewayv2_route" "health_get" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.health.id}"
}

resource "aws_apigatewayv2_route" "reservations_get" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /reservations"
  target    = "integrations/${aws_apigatewayv2_integration.reservations.id}"
}

resource "aws_apigatewayv2_route" "reservations_post" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /reservations"
  target    = "integrations/${aws_apigatewayv2_integration.reservations.id}"
}

resource "aws_apigatewayv2_route" "reservation_id_get" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /reservations/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.reservations.id}"
}

resource "aws_apigatewayv2_route" "reservation_id_delete" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "DELETE /reservations/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.reservations.id}"
}

resource "aws_lambda_permission" "health" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.health_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "reservations" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.reservations_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
resource "aws_apigatewayv2_stage" "api" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = var.environment
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit    = var.throttle_rate_limit
    throttling_burst_limit   = var.throttle_burst_limit
    detailed_metrics_enabled = false
  }
}
