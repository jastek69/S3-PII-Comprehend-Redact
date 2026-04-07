################################################################################
# PII REDACTION LAMBDA FUNCTION
# Integrates with S3 Object Lambda and Amazon Comprehend
# Supports multiple document formats: PDF, TXT, JSON, CSV
# Based on: https://docs.aws.amazon.com/AmazonS3/latest/userguide/tutorial-s3-object-lambda-redact-pii.html
################################################################################

# Package the Lambda function code (API Gateway handler)
data "archive_file" "pii_redaction_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/api-gateway-handler.py"
  output_path = "${path.module}/lambda/pii_redaction.zip"
}

# Lambda Layer for PDF processing dependencies (PyPDF2, reportlab)
# Note: You need to build this layer separately. See lambda/build-layer.sh
resource "aws_lambda_layer_version" "pdf_dependencies" {
  count               = fileexists("${path.module}/lambda/pdf-layer.zip") ? 1 : 0
  filename            = "${path.module}/lambda/pdf-layer.zip"
  layer_name          = "pii-redaction-pdf-dependencies"
  compatible_runtimes = ["python3.12", "python3.11"]
  description         = "PDF processing dependencies: PyPDF2 and reportlab"

  source_code_hash = fileexists("${path.module}/lambda/pdf-layer.zip") ? filebase64sha256("${path.module}/lambda/pdf-layer.zip") : null
}

# CloudWatch Log Group for Lambda function
resource "aws_cloudwatch_log_group" "pii_redaction_lambda_logs" {
  name              = "/aws/lambda/${var.pii_lambda_function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "PII Redaction Lambda Logs"
    Purpose     = "PII Redaction with S3 Object Lambda"
    Environment = "production"
  }
}

# Lambda function for PII redaction
resource "aws_lambda_function" "pii_redaction_lambda" {
  filename         = data.archive_file.pii_redaction_lambda_zip.output_path
  function_name    = var.pii_lambda_function_name
  role             = aws_iam_role.pii_redaction_lambda_role.arn
  handler          = "api-gateway-handler.lambda_handler"
  source_code_hash = data.archive_file.pii_redaction_lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 600  # 10 minutes for Textract async processing
  memory_size      = var.lambda_memory_size

  # Attach PDF processing layer if available
  layers = fileexists("${path.module}/lambda/pdf-layer.zip") ? [aws_lambda_layer_version.pdf_dependencies[0].arn] : []

  environment {
    variables = {
      MASK_CHARACTER    = var.mask_character
      MASK_MODE         = var.mask_mode
      PII_ENTITY_TYPES  = var.pii_entity_types
      COMPREHEND_REGION = var.aws_region  # Use same region as deployment
      LOG_LEVEL         = "INFO"
    }
  }

  tags = {
    Name        = var.pii_lambda_function_name
    Purpose     = "PII Redaction with Amazon Comprehend - API Gateway"
    Environment = "production"
  }

  depends_on = [
    aws_cloudwatch_log_group.pii_redaction_lambda_logs,
    aws_iam_role_policy_attachment.pii_lambda_comprehend_policy,
    aws_iam_role_policy_attachment.pii_lambda_s3_policy
  ]
}


