# Offline variable-validation tests for the root infrastructure module.
#
# Run with:
#   cd infrastructure
#   terraform test -filter=tests/variables.tftest.hcl
#
# All providers are mocked so no AWS credentials or network access are needed.
# The archive provider is mocked because modules/lambda uses data "archive_file".
#
# Each "expect_failures" run asserts that the root variable's validation block
# correctly rejects an invalid value.  Happy-path runs assert that valid inputs
# produce a successful (but mocked) plan.

mock_provider "aws" {}
mock_provider "archive" {}

# ---------------------------------------------------------------------------
# Shared defaults – overridden per run block where needed.
# ---------------------------------------------------------------------------
variables {
  aws_region           = "us-east-1"
  environment          = "dev"
  amplify_github_token = "test-placeholder"
}

# ---------------------------------------------------------------------------
# var.environment
# ---------------------------------------------------------------------------
run "environment_valid_dev" {
  command = plan
  variables {
    environment = "dev"
  }
}

run "environment_valid_prod" {
  command = plan
  variables {
    environment = "prod"
  }
}

run "environment_rejects_staging" {
  command = plan
  variables {
    environment = "staging"
  }
  expect_failures = [var.environment]
}

run "environment_rejects_empty" {
  command = plan
  variables {
    environment = ""
  }
  expect_failures = [var.environment]
}

# ---------------------------------------------------------------------------
# var.cloudwatch_log_retention_days
# ---------------------------------------------------------------------------
run "log_retention_valid_1" {
  command = plan
  variables {
    cloudwatch_log_retention_days = 1
  }
}

run "log_retention_valid_7" {
  command = plan
  variables {
    cloudwatch_log_retention_days = 7
  }
}

run "log_retention_valid_30" {
  command = plan
  variables {
    cloudwatch_log_retention_days = 30
  }
}

run "log_retention_rejects_2" {
  command = plan
  variables {
    cloudwatch_log_retention_days = 2
  }
  expect_failures = [var.cloudwatch_log_retention_days]
}

run "log_retention_rejects_0" {
  command = plan
  variables {
    cloudwatch_log_retention_days = 0
  }
  expect_failures = [var.cloudwatch_log_retention_days]
}

run "log_retention_rejects_365" {
  command = plan
  variables {
    cloudwatch_log_retention_days = 365
  }
  expect_failures = [var.cloudwatch_log_retention_days]
}

# ---------------------------------------------------------------------------
# var.lambda_reserved_concurrency
# ---------------------------------------------------------------------------
run "concurrency_valid_unreserved" {
  command = plan
  variables {
    lambda_reserved_concurrency = -1
  }
}

run "concurrency_valid_zero" {
  command = plan
  variables {
    lambda_reserved_concurrency = 0
  }
}

run "concurrency_valid_positive" {
  command = plan
  variables {
    lambda_reserved_concurrency = 5
  }
}

run "concurrency_rejects_negative_two" {
  command = plan
  variables {
    lambda_reserved_concurrency = -2
  }
  expect_failures = [var.lambda_reserved_concurrency]
}

# ---------------------------------------------------------------------------
# var.amplify_custom_domain_name
# ---------------------------------------------------------------------------
run "domain_valid_empty" {
  command = plan
  variables {
    amplify_custom_domain_name = ""
  }
}

run "domain_valid_subdomain" {
  command = plan
  variables {
    amplify_custom_domain_name = "app.example.com"
  }
}

run "domain_valid_apex" {
  command = plan
  variables {
    amplify_custom_domain_name = "example.com"
  }
}

run "domain_rejects_spaces" {
  command = plan
  variables {
    amplify_custom_domain_name = "not a valid domain"
  }
  expect_failures = [var.amplify_custom_domain_name]
}

run "domain_rejects_exclamation" {
  command = plan
  variables {
    amplify_custom_domain_name = "bad!domain.com"
  }
  expect_failures = [var.amplify_custom_domain_name]
}
