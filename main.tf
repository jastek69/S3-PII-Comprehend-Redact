################################################################################
# PII REDACTION WITH S3 OBJECT LAMBDA AND AMAZON COMPREHEND
# Main configuration file
#
# Architecture:
# 1. S3 Bucket (stores original PII data with all public access blocked)
# 2. Standard S3 Access Point (supporting access point)
# 3. Lambda Function (uses Amazon Comprehend to detect and redact PII)
# 4. S3 Object Lambda Access Point (intercepts GetObject requests)
#
# When a client requests an object through the Object Lambda Access Point:
# - S3 invokes the Lambda function
# - Lambda retrieves the original object
# - Lambda calls Amazon Comprehend to detect PII
# - Lambda redacts the PII and returns the redacted content
# - Client receives redacted data (original files remain unchanged)
#
# Reference: https://docs.aws.amazon.com/AmazonS3/latest/userguide/tutorial-s3-object-lambda-redact-pii.html
################################################################################

# Local variables for consistent naming
locals {
  name_prefix = "${var.project_name}-${var.aws_region}"
  
  # Custom domain for API Gateway
  api_subdomain       = "pii-api"
  api_domain_name     = "${local.api_subdomain}.${var.domain_name}"
  
  # Legacy origin record name (if needed for other resources)
  origin_record_name  = "${var.api_gateway_origin_subdomain}.${var.domain_name}"
  
  common_tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Purpose     = "PII Redaction"
    Region      = var.aws_region
    Environment = "production"
  }
}

# The S3 bucket, access points, Lambda function, and IAM roles
# are defined in their respective files:
# - s3.tf: S3 bucket and access points
# - lambda.tf: Lambda function configuration
# - iam.tf: IAM roles and policies
# - variables.tf: Configuration variables

