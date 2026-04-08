################################################################################
# API GATEWAY ALTERNATIVE TO S3 OBJECT LAMBDA
# Provides PII redaction through REST API instead of S3 Object Lambda
# Access Pattern: https://api-id.execute-api.region.amazonaws.com/prod/{bucket}/{key}
################################################################################

# API Gateway REST API
resource "aws_api_gateway_rest_api" "pii_redaction_api" {
  name        = "${var.project_name}-pii-redaction-api"
  description = "API Gateway for PII redaction - Alternative to S3 Object Lambda"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "${var.project_name}-pii-redaction-api"
    Purpose     = "PII Redaction API"
    Environment = "production"
  }
}

# Root resource for bucket
resource "aws_api_gateway_resource" "bucket" {
  rest_api_id = aws_api_gateway_rest_api.pii_redaction_api.id
  parent_id   = aws_api_gateway_rest_api.pii_redaction_api.root_resource_id
  path_part   = "{bucket}"
}

# Resource for key (file path) - greedy to capture full path
resource "aws_api_gateway_resource" "key" {
  rest_api_id = aws_api_gateway_rest_api.pii_redaction_api.id
  parent_id   = aws_api_gateway_resource.bucket.id
  path_part   = "{key+}"
}

# GET method on key resource
resource "aws_api_gateway_method" "get_object" {
  rest_api_id   = aws_api_gateway_rest_api.pii_redaction_api.id
  resource_id   = aws_api_gateway_resource.key.id
  http_method   = "GET"
  authorization = "AWS_IAM"  # Require AWS signature

  request_parameters = {
    "method.request.path.bucket" = true
    "method.request.path.key"    = true
  }
}

# OPTIONS method for CORS preflight
resource "aws_api_gateway_method" "options_object" {
  rest_api_id   = aws_api_gateway_rest_api.pii_redaction_api.id
  resource_id   = aws_api_gateway_resource.key.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# OPTIONS integration (mock)
resource "aws_api_gateway_integration" "options" {
  rest_api_id = aws_api_gateway_rest_api.pii_redaction_api.id
  resource_id = aws_api_gateway_resource.key.id
  http_method = aws_api_gateway_method.options_object.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# OPTIONS method response
resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.pii_redaction_api.id
  resource_id = aws_api_gateway_resource.key.id
  http_method = aws_api_gateway_method.options_object.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

# OPTIONS integration response
resource "aws_api_gateway_integration_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.pii_redaction_api.id
  resource_id = aws_api_gateway_resource.key.id
  http_method = aws_api_gateway_method.options_object.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent,X-Amz-Content-Sha256,X-Amz-Target,X-Amz-Invocation-Type,Accept,Accept-Language'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Lambda integration
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.pii_redaction_api.id
  resource_id = aws_api_gateway_resource.key.id
  http_method = aws_api_gateway_method.get_object.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.pii_redaction_lambda.invoke_arn
}

# Method response
resource "aws_api_gateway_method_response" "get_object_200" {
  rest_api_id = aws_api_gateway_rest_api.pii_redaction_api.id
  resource_id = aws_api_gateway_resource.key.id
  http_method = aws_api_gateway_method.get_object.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Content-Type"                 = true
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

# Deploy API
resource "aws_api_gateway_deployment" "prod" {
  rest_api_id = aws_api_gateway_rest_api.pii_redaction_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.bucket.id,
      aws_api_gateway_resource.key.id,
      aws_api_gateway_method.get_object.id,
      aws_api_gateway_method.options_object.id,
      aws_api_gateway_integration.lambda.id,
      aws_api_gateway_integration.options.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration.options
  ]
}

# Stage
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.prod.id
  rest_api_id   = aws_api_gateway_rest_api.pii_redaction_api.id
  stage_name    = "prod"

  tags = {
    Name        = "${var.project_name}-prod-stage"
    Environment = "production"
  }
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pii_redaction_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.pii_redaction_api.execution_arn}/*/*"
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.pii_redaction_api.name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name    = "API Gateway Logs"
    Purpose = "PII Redaction API Logging"
  }
}

# API Gateway account settings for CloudWatch
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

# IAM role for API Gateway CloudWatch logging
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.project_name}-api-gateway-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}
