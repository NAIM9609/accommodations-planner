locals {
  prefix = "${var.app_name}-${var.environment}"
}

module "dynamodb" {
  source      = "./modules/dynamodb"
  table_name  = "${local.prefix}-reservations"
  environment = var.environment
}

module "lambda" {
  source               = "./modules/lambda"
  prefix               = local.prefix
  environment          = var.environment
  dynamodb_table_arn   = module.dynamodb.table_arn
  dynamodb_table_name  = module.dynamodb.table_name
}

module "api_gateway" {
  source                   = "./modules/api_gateway"
  prefix                   = local.prefix
  environment              = var.environment
  health_lambda_arn        = module.lambda.health_lambda_arn
  health_lambda_name       = module.lambda.health_lambda_name
  reservations_lambda_arn  = module.lambda.reservations_lambda_arn
  reservations_lambda_name = module.lambda.reservations_lambda_name
}

module "amplify" {
  source       = "./modules/amplify"
  prefix       = local.prefix
  environment  = var.environment
  github_repo  = var.github_repo
  github_token = var.amplify_github_token
  api_base_url = module.api_gateway.api_url
}

# GitHub OIDC provider for CI/CD (create once per AWS account)
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

resource "aws_iam_role" "github_actions" {
  name = "${local.prefix}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions" {
  name = "${local.prefix}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction",
          "lambda:PublishVersion",
          "lambda:UpdateAlias",
          "lambda:PublishLayerVersion",
          "lambda:GetLayerVersion",
          "lambda:UpdateFunctionConfiguration",
          "apigateway:*",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "dynamodb:DescribeTable"
        ]
        Resource = "*"
      }
    ]
  })
}
