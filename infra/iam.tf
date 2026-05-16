# IAM Role for Cloud Custodian Lambda functions
resource "aws_iam_role" "custodian_lambda" {
  name = "CloudCustodianLambdaRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Policy: Read access to resources for scanning
resource "aws_iam_policy" "custodian_read" {
  name        = "CloudCustodianReadPolicy"
  description = "Read-only access for Cloud Custodian to scan resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2ReadAccess"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:CreateTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3ReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetBucket*",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketPolicyStatus",
          "s3:GetBucketTagging",
          "s3:ListAllMyBuckets",
          "s3:ListBucket",
          "s3:PutBucketTagging"
        ]
        Resource = "*"
      },
      {
        Sid    = "EBSReadAccess"
        Effect = "Allow"
        Action = [
          "ebs:Describe*",
          "ec2:DescribeVolumes"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudTrailReadOnly"
        Effect = "Allow"
        Action = [
          "cloudtrail:LookupEvents",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:DescribeTrails",
          "cloudtrail:ListTrails",
          "cloudtrail:GetEventSelectors"
        ]
        Resource = "*"
      },
      {
        Sid    = "TagReadAccess"
        Effect = "Allow"
        Action = [
          "tag:GetResources",
          "tag:GetTagKeys",
          "tag:GetTagValues"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMReadAccess"
        Effect = "Allow"
        Action = [
          "iam:List*",
          "iam:Get*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy: Write results to S3
resource "aws_iam_policy" "custodian_s3_write" {
  name        = "CloudCustodianS3WritePolicy"
  description = "Allow Cloud Custodian to write results to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3WriteResults"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.custodian_results.arn,
          "${aws_s3_bucket.custodian_results.arn}/*"
        ]
      }
    ]
  })
}

# Policy: CloudWatch Logs for Lambda
resource "aws_iam_policy" "custodian_logs" {
  name        = "CloudCustodianLogsPolicy"
  description = "Allow Cloud Custodian Lambda to write CloudWatch logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:*"
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policies to Lambda role
resource "aws_iam_role_policy_attachment" "custodian_read" {
  role       = aws_iam_role.custodian_lambda.name
  policy_arn = aws_iam_policy.custodian_read.arn
}

resource "aws_iam_role_policy_attachment" "custodian_s3_write" {
  role       = aws_iam_role.custodian_lambda.name
  policy_arn = aws_iam_policy.custodian_s3_write.arn
}

resource "aws_iam_role_policy_attachment" "custodian_logs" {
  role       = aws_iam_role.custodian_lambda.name
  policy_arn = aws_iam_policy.custodian_logs.arn
}

# IAM Role for Dashboard (EC2 instance profile)
resource "aws_iam_role" "dashboard" {
  name = "CloudCustodianDashboardRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Dashboard policy: Read S3 results + CloudTrail read-only
resource "aws_iam_policy" "dashboard_read" {
  name        = "CloudCustodianDashboardPolicy"
  description = "Allow dashboard to read results from S3 and CloudTrail"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadResultsFromS3"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.custodian_results.arn,
          "${aws_s3_bucket.custodian_results.arn}/*"
        ]
      },
      {
        Sid    = "CloudTrailReadOnly"
        Effect = "Allow"
        Action = [
          "cloudtrail:LookupEvents",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:DescribeTrails"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dashboard_read" {
  role       = aws_iam_role.dashboard.name
  policy_arn = aws_iam_policy.dashboard_read.arn
}

resource "aws_iam_instance_profile" "dashboard" {
  name = "CloudCustodianDashboardProfile"
  role = aws_iam_role.dashboard.name
}
