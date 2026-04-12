locals {
  prefix           = "${var.app_name}-${var.environment}"
  oidc_sub_pattern = var.environment == "prod" ? "repo:${var.github_repo}:ref:refs/heads/master" : "repo:${var.github_repo}:*"
  allowed_workflow_refs = [
    "${var.github_repo}/.github/workflows/deploy-backend.yml@*",
    "${var.github_repo}/.github/workflows/deploy-dev.yml@*",
    "${var.github_repo}/.github/workflows/deploy-prod.yml@*",
  ]
}

data "aws_caller_identity" "current" {}

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
  reserved_concurrency = var.lambda_reserved_concurrency
  log_retention_days   = var.cloudwatch_log_retention_days
}

module "api_gateway" {
  source                   = "./modules/api_gateway"
  prefix                   = local.prefix
  environment              = var.environment
  health_lambda_arn        = module.lambda.health_lambda_arn
  health_lambda_name       = module.lambda.health_lambda_name
  reservations_lambda_arn  = module.lambda.reservations_lambda_arn
  reservations_lambda_name = module.lambda.reservations_lambda_name
  throttle_rate_limit      = var.api_throttle_rate_limit
  throttle_burst_limit     = var.api_throttle_burst_limit
}

module "amplify" {
  source        = "./modules/amplify"
  prefix        = local.prefix
  environment   = var.environment
  github_repo   = var.github_repo
  github_branch = var.github_branch
  github_token  = var.amplify_github_token
  api_base_url  = module.api_gateway.api_url
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
          "token.actions.githubusercontent.com:sub"              = local.oidc_sub_pattern
          "token.actions.githubusercontent.com:job_workflow_ref" = local.allowed_workflow_refs
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
          "amplify:CreateApp",
          "amplify:DeleteApp",
          "amplify:GetApp",
          "amplify:UpdateApp",
          "amplify:CreateBranch",
          "amplify:DeleteBranch",
          "amplify:GetBranch",
          "amplify:UpdateBranch",
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction",
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:PublishVersion",
          "lambda:UpdateAlias",
          "lambda:PublishLayerVersion",
          "lambda:DeleteLayerVersion",
          "lambda:GetLayerVersion",
          "lambda:UpdateFunctionConfiguration",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "apigateway:GET",
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:PATCH",
          "apigateway:DELETE",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:CreateTable",
          "dynamodb:DeleteTable",
          "dynamodb:UpdateTable",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:UpdateAssumeRolePolicy",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:AddClientIDToOpenIDConnectProvider",
          "iam:RemoveClientIDFromOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:DeleteRetentionPolicy"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunction"
        ]
        Resource = [
          "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${local.prefix}-*"
        ]
      }
    ]
  })
}
