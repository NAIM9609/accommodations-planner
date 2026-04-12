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
  }
}
