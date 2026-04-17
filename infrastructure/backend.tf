# Remote state stored in S3 + DynamoDB lock (both free-tier friendly)
# Bootstrap with the AWS CLI commands in README.md

terraform {
  backend "s3" {}
}
