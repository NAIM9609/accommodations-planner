# Production defaults tuned for minimal spend while keeping service usable.
github_branch                 = "master"
lambda_reserved_concurrency   = 1
cloudwatch_log_retention_days = 1
api_throttle_rate_limit       = 2
api_throttle_burst_limit      = 4
