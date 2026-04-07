################################################################################
# IAM ROLES AND POLICIES FOR PII REDACTION
# Lambda execution role with permissions for:
# - Amazon Comprehend (PII detection)
# - S3 Object Lambda (write response)
# - CloudWatch Logs
################################################################################

# IAM role for PII redaction Lambda function
resource "aws_iam_role" "pii_redaction_lambda_role" {
  name = var.pii_lambda_role_name

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
    Name        = var.pii_lambda_role_name
    Purpose     = "PII Redaction Lambda Execution"
    Environment = "production"
  }
}

# Policy for Amazon Comprehend and Textract access
resource "aws_iam_policy" "pii_lambda_comprehend_policy" {
  name        = "${var.pii_lambda_role_name}-comprehend-policy"
  description = "Allow Lambda to call Amazon Comprehend for PII detection and Textract for OCR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "comprehend:DetectPiiEntities",
          "comprehend:ContainsPiiEntities"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "textract:DetectDocumentText",
          "textract:AnalyzeDocument",
          "textract:StartDocumentTextDetection",
          "textract:GetDocumentTextDetection"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.pii_lambda_role_name}-comprehend-policy"
    Purpose     = "Amazon Comprehend PII Detection and Textract OCR"
    Environment = "production"
  }
}

# Policy for S3 Object Lambda operations
resource "aws_iam_policy" "pii_lambda_s3_policy" {
  name        = "${var.pii_lambda_role_name}-s3-policy"
  description = "Allow Lambda to interact with S3 Object Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3-object-lambda:WriteGetObjectResponse"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.pii_data_bucket.arn,
          "${aws_s3_bucket.pii_data_bucket.arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.pii_lambda_role_name}-s3-policy"
    Purpose     = "S3 Object Lambda Access"
    Environment = "production"
  }
}

# Attach Comprehend policy to Lambda role
resource "aws_iam_role_policy_attachment" "pii_lambda_comprehend_policy" {
  role       = aws_iam_role.pii_redaction_lambda_role.name
  policy_arn = aws_iam_policy.pii_lambda_comprehend_policy.arn
}

# Attach S3 policy to Lambda role
resource "aws_iam_role_policy_attachment" "pii_lambda_s3_policy" {
  role       = aws_iam_role.pii_redaction_lambda_role.name
  policy_arn = aws_iam_policy.pii_lambda_s3_policy.arn
}

# Attach AWS managed policy for basic Lambda execution (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "pii_lambda_basic_execution" {
  role       = aws_iam_role.pii_redaction_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

################################################################################
# LEGACY IAM CONFIGURATION (KEEP IF NEEDED FOR OTHER RESOURCES)
################################################################################

# CloudFront/WAF Service Role
resource "aws_iam_role" "cloudfront_service_role" {
  name = "cloudfront-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "cloudfront-service-role"
    Service = "CloudFront"
    Scope   = "Global"
  }
}

# Lambda@Edge Execution Role
resource "aws_iam_role" "lambda_edge_role" {
  name = "lambda-edge-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "edgelambda.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = {
    Name    = "lambda-edge-role"
    Service = "LambdaEdge"
    Scope   = "Global"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_edge_basic_execution" {
  role       = aws_iam_role.lambda_edge_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


################################################################################
# BEDROCK / AI SERVICE ROLES
################################################################################
/*
TO:DO
# Bedrock Service Role
resource "aws_iam_role" "bedrock_service_role" {
  name = "bedrock-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "bedrock-service-role"
    Service = "Bedrock"
    Scope   = "Global"
  }
}

# Bedrock Application Access Policy
data "aws_iam_policy_document" "bedrock_application_access" {
  statement {
    sid    = "BedrockInvoke"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]
    resources = [
      "arn:aws:bedrock:ap-northeast-1::foundation-model/*",
      "arn:aws:bedrock:sa-east-1::foundation-model/*"
    ]
  }

  statement {
    sid    = "BedrockKnowledgeBase"
    effect = "Allow"
    actions = [
      "bedrock:Retrieve",
      "bedrock:RetrieveAndGenerate"
    ]
    resources = [
      "arn:aws:bedrock:us-west-1:${data.aws_caller_identity.taaops_self01.account_id}:knowledge-base/*"
    ]
  }
}

resource "aws_iam_policy" "bedrock_application_access" {
  name        = "bedrock-application-access"
  description = "Application access to Bedrock services"
  policy      = data.aws_iam_policy_document.bedrock_application_access.json
}
*/

################################################################################
# ROUTE53 / DNS MANAGEMENT ROLES
################################################################################

# Route53 Health Check Role
resource "aws_iam_role" "route53_health_check_role" {
  name = "route53-health-check-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "route53.amazonaws.com"
        }
      }
    ]
  })
}

# Route53 CloudWatch Integration Policy
data "aws_iam_policy_document" "route53_cloudwatch" {
  statement {
    sid    = "Route53CloudWatchMetrics"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["AWS/Route53"]
    }
  }
}

resource "aws_iam_policy" "route53_cloudwatch" {
  name        = "route53-cloudwatch-policy"
  description = "Route53 CloudWatch integration"
  policy      = data.aws_iam_policy_document.route53_cloudwatch.json
}

resource "aws_iam_role_policy_attachment" "route53_cloudwatch" {
  role       = aws_iam_role.route53_health_check_role.name
  policy_arn = aws_iam_policy.route53_cloudwatch.arn
}
