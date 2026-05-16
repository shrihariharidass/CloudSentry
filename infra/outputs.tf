output "s3_results_bucket" {
  description = "S3 bucket for Cloud Custodian results"
  value       = aws_s3_bucket.custodian_results.bucket
}

output "s3_cloudtrail_bucket" {
  description = "S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail_logs.bucket
}

output "lambda_role_arn" {
  description = "IAM Role ARN for Cloud Custodian Lambda"
  value       = aws_iam_role.custodian_lambda.arn
}

output "dashboard_instance_profile" {
  description = "Instance profile for dashboard EC2"
  value       = aws_iam_instance_profile.dashboard.name
}

output "cloudtrail_name" {
  description = "CloudTrail trail name"
  value       = aws_cloudtrail.custodian.name
}
