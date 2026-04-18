terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_amplify_app" "frontend" {
  name         = "${var.prefix}-frontend"
  repository   = "https://github.com/${var.github_repo}"
  access_token = var.github_token

  build_spec = <<-EOT
    version: 1
    frontend:
      phases:
        preBuild:
          commands:
            - cd frontend
            - npm ci
        build:
          commands:
            - npm run build
      artifacts:
        baseDirectory: frontend/out
        files:
          - '**/*'
      cache:
        paths:
          - frontend/node_modules/**/*
  EOT

  environment_variables = {
    NEXT_PUBLIC_API_BASE_URL = var.api_base_url
    NEXT_PUBLIC_STAGE        = var.environment
  }

  custom_rule {
    source = "/<*>"
    status = "404-200"
    target = "/404.html"
  }

}

resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.frontend.id
  branch_name = var.github_branch
  framework   = "Next.js - SSG"
  stage       = var.environment == "prod" ? "PRODUCTION" : "DEVELOPMENT"

  environment_variables = {
    NEXT_PUBLIC_API_BASE_URL = var.api_base_url
    NEXT_PUBLIC_STAGE        = var.environment
  }

}

resource "aws_amplify_domain_association" "custom" {
  count = var.custom_domain_enabled ? 1 : 0

  app_id      = aws_amplify_app.frontend.id
  domain_name = var.custom_domain_name

  sub_domain {
    branch_name = aws_amplify_branch.main.branch_name
    prefix      = var.custom_domain_prefix
  }

}
