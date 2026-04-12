# Remote state stored in S3 + DynamoDB lock (both free-tier friendly)
# Bootstrap with the AWS CLI commands in README.md
# Uncomment when S3 bucket is created:
#
# terraform {
#   backend "s3" {
#     bucket         = "accommodations-planner-tf-state"
#     key            = "accommodations-planner/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "accommodations-planner-tf-lock"
#     encrypt        = true
#   }
# }
#
# For local development, state is stored locally (default).
# See README.md for instructions on enabling remote state.
