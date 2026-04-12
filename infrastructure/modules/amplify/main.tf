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
        baseDirectory: frontend/.next
        files:
          - '**/*'
      cache:
        paths:
          - frontend/node_modules/**/*
  EOT

  environment_variables = {
    NEXT_PUBLIC_API_BASE_URL = var.api_base_url
    NEXT_PUBLIC_STAGE        = var.environment
    BACKEND_API_URL          = var.api_base_url
    _LIVE_UPDATES            = jsonencode([{ name = "Next.js version", pkg = "next-version", type = "internal", version = "latest" }])
  }

  custom_rule {
    source = "/<*>"
    status = "404"
    target = "/index.html"
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
    BACKEND_API_URL          = var.api_base_url
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
