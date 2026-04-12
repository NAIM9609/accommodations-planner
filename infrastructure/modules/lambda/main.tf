locals {
  lambda_common = {
    role             = aws_iam_role.lambda.arn
    runtime          = "nodejs20.x"
    timeout          = 10
    memory_size      = 128
    filename         = data.archive_file.lambda_placeholder.output_path
    source_code_hash = data.archive_file.lambda_placeholder.output_base64sha256
  }
  log_retention_days = var.log_retention_days
}

data "archive_file" "lambda_placeholder" {
  type        = "zip"
  output_path = "${path.module}/lambda_placeholder.zip"

  source {
    content  = "exports.handler = async () => ({ statusCode: 200, body: 'placeholder' });"
    filename = "index.js"
  }
}

data "archive_file" "layer_placeholder" {
  type        = "zip"
  output_path = "${path.module}/layer_placeholder.zip"

  source {
    content  = "{}"
    filename = "nodejs/package.json"
  }
}

resource "aws_lambda_layer_version" "deps" {
  layer_name          = "${var.prefix}-deps"
  filename            = data.archive_file.layer_placeholder.output_path
  source_code_hash    = data.archive_file.layer_placeholder.output_base64sha256
  compatible_runtimes = ["nodejs20.x"]
}

resource "aws_lambda_function" "health" {
  function_name                  = "${var.prefix}-health"
  role                           = local.lambda_common.role
  handler                        = "handlers/health.handler"
  runtime                        = local.lambda_common.runtime
  timeout                        = local.lambda_common.timeout
  memory_size                    = local.lambda_common.memory_size
  filename                       = local.lambda_common.filename
  source_code_hash               = local.lambda_common.source_code_hash
  layers                         = [aws_lambda_layer_version.deps.arn]
  reserved_concurrent_executions = var.reserved_concurrency

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  lifecycle {
    ignore_changes = [filename, source_code_hash, layers]
  }
}

resource "aws_lambda_function" "reservations" {
  function_name                  = "${var.prefix}-reservations"
  role                           = local.lambda_common.role
  handler                        = "handlers/reservations.handler"
  runtime                        = local.lambda_common.runtime
  timeout                        = local.lambda_common.timeout
  memory_size                    = local.lambda_common.memory_size
  filename                       = local.lambda_common.filename
  source_code_hash               = local.lambda_common.source_code_hash
  layers                         = [aws_lambda_layer_version.deps.arn]
  reserved_concurrent_executions = var.reserved_concurrency

  environment {
    variables = {
      ENVIRONMENT         = var.environment
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
    }
  }

  lifecycle {
    ignore_changes = [filename, source_code_hash, layers]
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  for_each = toset([
    aws_lambda_function.health.function_name,
    aws_lambda_function.reservations.function_name,
  ])
  name              = "/aws/lambda/${each.value}"
  retention_in_days = local.log_retention_days
}

resource "aws_iam_role" "lambda" {
  name = "${var.prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${var.prefix}-lambda-dynamodb"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:DeleteItem",
        "dynamodb:Scan",
        "dynamodb:Query"
      ]
      Resource = var.dynamodb_table_arn
    }]
  })
}
