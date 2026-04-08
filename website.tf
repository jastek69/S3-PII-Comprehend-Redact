################################################################################
# S3 STATIC WEBSITE FOR PII REDACTION UI
# Hosts the web interface for uploading and redacting documents
################################################################################

# S3 bucket for static website hosting
resource "aws_s3_bucket" "pii_website" {
  bucket_prefix = "pii-redaction-ui-"

  tags = {
    Name        = "PII Redaction Web UI"
    Purpose     = "Static website hosting"
    Environment = "production"
  }
}

# Enable static website hosting
resource "aws_s3_bucket_website_configuration" "pii_website" {
  bucket = aws_s3_bucket.pii_website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Public access block (we'll allow public read for website)
resource "aws_s3_bucket_public_access_block" "pii_website" {
  bucket = aws_s3_bucket.pii_website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket policy for public read access
resource "aws_s3_bucket_policy" "pii_website" {
  bucket = aws_s3_bucket.pii_website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.pii_website.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.pii_website]
}

# Upload website files
resource "aws_s3_object" "website_index" {
  bucket       = aws_s3_bucket.pii_website.id
  key          = "index.html"
  source       = "${path.module}/web/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/web/index.html")
}

resource "aws_s3_object" "website_css" {
  bucket       = aws_s3_bucket.pii_website.id
  key          = "styles.css"
  source       = "${path.module}/web/styles.css"
  content_type = "text/css"
  etag         = filemd5("${path.module}/web/styles.css")
}

resource "aws_s3_object" "website_js" {
  bucket       = aws_s3_bucket.pii_website.id
  key          = "app.js"
  source       = "${path.module}/web/app.js"
  content_type = "application/javascript"
  etag         = filemd5("${path.module}/web/app.js")
}

# Generate config.js with actual deployment values
resource "aws_s3_object" "website_config" {
  bucket       = aws_s3_bucket.pii_website.id
  key          = "config.js"
  content_type = "application/javascript"
  content = templatefile("${path.module}/web/config.js.tpl", {
    api_url     = "https://${aws_api_gateway_domain_name.pii_api.domain_name}"
    bucket_name = aws_s3_bucket.pii_data_bucket.id
    region      = data.aws_region.current.name
  })
}

# Output website URL
output "website_url" {
  description = "URL of the PII redaction web interface"
  value       = "http://${aws_s3_bucket_website_configuration.pii_website.website_endpoint}"
}

output "website_bucket_name" {
  description = "Name of the website S3 bucket"
  value       = aws_s3_bucket.pii_website.id
}
