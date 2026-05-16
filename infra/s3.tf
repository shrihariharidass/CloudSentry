# S3 bucket to store Cloud Custodian policy results and logs
resource "aws_s3_bucket" "custodian_results" {
  bucket = "custodian-results-${var.account_id}"

  tags = {
    Name        = "custodian-results"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_s3_bucket_versioning" "custodian_results" {
  bucket = aws_s3_bucket.custodian_results.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "custodian_results" {
  bucket = aws_s3_bucket.custodian_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "custodian_results" {
  bucket = aws_s3_bucket.custodian_results.id

  rule {
    id     = "expire-old-results"
    status = "Enabled"

    expiration {
      days = 90
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "custodian_results" {
  bucket = aws_s3_bucket.custodian_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
