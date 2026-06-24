output "tfstate_bucket_name" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.tfstate.bucket
}

output "tfstate_dynamodb_table" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.tfstate_lock.name
}

output "github_oidc_provider_arn" {
  description = "ARN of GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_terraform_role_arn" {
  description = "ARN of IAM role for GitHub Actions Terraform operations"
  value       = aws_iam_role.github_actions_terraform.arn
}

output "github_actions_deploy_role_arn" {
  description = "ARN of IAM role for GitHub Actions deploy operations"
  value       = aws_iam_role.github_actions_deploy.arn
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}