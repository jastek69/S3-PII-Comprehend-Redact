################################################################################
# S3 BUCKET FOR PII REDACTION
# Note: S3 Object Lambda Access Point removed due to service availability
# Using API Gateway + Lambda instead for PII redaction
################################################################################

# Data source for AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 bucket with PII data
resource "aws_s3_bucket" "pii_data_bucket" {
  bucket_prefix = "pii-data-bucket-"
  force_destroy = var.force_destroy

  tags = {
    Name        = "PII Data Bucket"
    Purpose     = "PII Redaction with API Gateway"
    Region      = data.aws_region.current.name
    Environment = "production"
  }
}

# Block ALL public access (AWS best practice for PII data)
resource "aws_s3_bucket_public_access_block" "pii_data_bucket_pab" {
  bucket = aws_s3_bucket.pii_data_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for data protection
resource "aws_s3_bucket_versioning" "pii_data_bucket_versioning" {
  bucket = aws_s3_bucket.pii_data_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "pii_data_bucket_encryption" {
  bucket = aws_s3_bucket.pii_data_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Ownership controls (disable ACLs, use bucket policies)
resource "aws_s3_bucket_ownership_controls" "pii_data_bucket_ownership" {
  bucket = aws_s3_bucket.pii_data_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

################################################################################
# OPTIONAL: S3 BUCKET FOR LOGS
################################################################################

resource "aws_s3_bucket" "pii_access_logs" {
  bucket_prefix = "pii-access-logs-"
  force_destroy = var.force_destroy

  tags = {
    Name        = "PII Access Logs Bucket"
    Purpose     = "Access logging for PII bucket"
    Region      = data.aws_region.current.name
    Environment = "production"
  }
}

# Block public access for logs bucket
resource "aws_s3_bucket_public_access_block" "pii_logs_pab" {
  bucket = aws_s3_bucket.pii_access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable logging on the main PII bucket (optional)
resource "aws_s3_bucket_logging" "pii_data_bucket_logging" {
  bucket = aws_s3_bucket.pii_data_bucket.id

  target_bucket = aws_s3_bucket.pii_access_logs.id
  target_prefix = "access-logs/"
}

