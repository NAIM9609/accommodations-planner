locals {
  prefix           = "${var.app_name}-${var.environment}"
  oidc_sub_pattern = var.environment == "prod" ? "repo:${var.github_repo}:ref:refs/heads/master" : "repo:${var.github_repo}:*"
  amplify_custom_domain_url = var.amplify_custom_domain_enabled ? (
    var.amplify_custom_domain_prefix != "" ? "https://${var.amplify_custom_domain_prefix}.${var.amplify_custom_domain_name}" : "https://${var.amplify_custom_domain_name}"
  ) : ""
  allowed_workflow_refs = [
    "${var.github_repo}/.github/workflows/deploy-backend.yml@*",
    "${var.github_repo}/.github/workflows/deploy-dev.yml@*",
    "${var.github_repo}/.github/workflows/deploy-prod.yml@*",
  ]
}

data "aws_caller_identity" "current" {}

check "amplify_custom_domain_requires_name" {
  assert {
    condition     = !var.amplify_custom_domain_enabled || length(trimspace(var.amplify_custom_domain_name)) > 0
    error_message = "Set amplify_custom_domain_name when amplify_custom_domain_enabled is true."
  }
}

module "dynamodb" {
  source      = "./modules/dynamodb"
  table_name  = "${local.prefix}-reservations"
  environment = var.environment
  allow_table_destroy = var.allow_dynamodb_destroy
}

module "lambda" {
  source               = "./modules/lambda"
  prefix               = local.prefix
  environment          = var.environment
  dynamodb_table_arn   = module.dynamodb.table_arn
  dynamodb_table_name  = module.dynamodb.table_name
  amplify_branch       = var.github_branch
  custom_domain_url    = local.amplify_custom_domain_url
  cors_allowed_origins = var.cors_additional_allowed_origins
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
  source                = "./modules/amplify"
  prefix                = local.prefix
  environment           = var.environment
  github_repo           = var.github_repo
  github_branch         = var.github_branch
  github_token          = var.amplify_github_token
  api_base_url          = module.api_gateway.api_url
  custom_domain_enabled = var.amplify_custom_domain_enabled
  custom_domain_name    = var.amplify_custom_domain_name
  custom_domain_prefix  = var.amplify_custom_domain_prefix
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
    Statement = [
      {
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
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions" {
  name = "${local.prefix}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Amplify: scoped to all apps in this account/region (app ID not known until first apply)
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
          "amplify:CreateDomainAssociation",
          "amplify:DeleteDomainAssociation",
          "amplify:GetDomainAssociation",
          "amplify:UpdateDomainAssociation",
        ]
        Resource = "arn:aws:amplify:${var.aws_region}:${data.aws_caller_identity.current.account_id}:apps/*"
      },
      {
        # Lambda: scoped to functions and layers with this stack's prefix
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:PublishVersion",
          "lambda:UpdateAlias",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:PublishLayerVersion",
          "lambda:DeleteLayerVersion",
          "lambda:GetLayerVersion",
          "lambda:AddPermission",
          "lambda:RemovePermission",
        ]
        Resource = [
          "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${local.prefix}-*",
          "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:layer:${local.prefix}-*",
          "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:layer:${local.prefix}-*:*",
        ]
      },
      {
        # API Gateway: scoped to this region (API IDs not known until first apply)
        Effect = "Allow"
        Action = [
          "apigateway:GET",
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:PATCH",
          "apigateway:DELETE",
        ]
        Resource = "arn:aws:apigateway:${var.aws_region}::*"
      },
      {
        # S3: Terraform state bucket name is set at bootstrap and not known here
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = "*"
      },
      {
        # DynamoDB: scoped to tables with this stack's prefix
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:CreateTable",
          "dynamodb:DeleteTable",
          "dynamodb:UpdateTable",
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${local.prefix}-*"
      },
      {
        # IAM role/policy management: scoped to roles with this stack's prefix
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:UpdateAssumeRolePolicy",
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.prefix}-*"
      },
      {
        # iam:PassRole scoped to Lambda execution role only to prevent privilege escalation
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.prefix}-lambda-*"
      },
      {
        # OIDC provider: scoped to GitHub Actions provider (deterministic ARN)
        Effect = "Allow"
        Action = [
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:AddClientIDToOpenIDConnectProvider",
          "iam:RemoveClientIDFromOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
      },
      {
        # CloudWatch Logs: scoped to Lambda log groups with this stack's prefix
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:DeleteRetentionPolicy",
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.prefix}-*"
      },
    ]
  })
}
