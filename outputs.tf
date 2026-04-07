################################################################################
# OUTPUTS FOR PII REDACTION INFRASTRUCTURE (API GATEWAY VERSION)
################################################################################

# S3 Bucket
output "pii_data_bucket_name" {
  description = "Name of the S3 bucket containing PII data"
  value       = aws_s3_bucket.pii_data_bucket.id
}

output "pii_data_bucket_arn" {
  description = "ARN of the S3 bucket containing PII data"
  value       = aws_s3_bucket.pii_data_bucket.arn
}

# API Gateway
output "api_gateway_url" {
  description = "Base URL of the API Gateway for PII redaction"
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "api_gateway_custom_domain_url" {
  description = "Custom domain URL for PII redaction API (cleaner URL)"
  value       = "https://${aws_api_gateway_domain_name.pii_api.domain_name}"
}

output "api_gateway_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.pii_redaction_api.id
}

# Lambda Function
output "pii_redaction_lambda_function_name" {
  description = "Name of the PII redaction Lambda function"
  value       = aws_lambda_function.pii_redaction_lambda.function_name
}

output "pii_redaction_lambda_arn" {
  description = "ARN of the PII redaction Lambda function"
  value       = aws_lambda_function.pii_redaction_lambda.arn
}

# IAM Role
output "pii_lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.pii_redaction_lambda_role.arn
}

# EC2 Instance
output "pii_ec2_public_ip" {
  description = "Public IP of EC2 instance for Lambda layer building"
  value       = aws_instance.pii.public_ip
}

output "pii_ec2_ssh_command" {
  description = "SSH command to connect to EC2"
  value       = "ssh -i piiKP.pem ec2-user@${aws_instance.pii.public_ip}"
}

output "pii_ec2_scp_layer_command" {
  description = "SCP command to download Lambda layer"
  value       = "scp -i piiKP.pem -o StrictHostKeyChecking=no ec2-user@${aws_instance.pii.public_ip}:/home/ec2-user/pdf-layer.zip ./lambda/"
}

# Configuration
output "pii_redaction_config" {
  description = "Current PII redaction configuration"
  value = {
    mask_character   = var.mask_character
    mask_mode        = var.mask_mode
    pii_entity_types = var.pii_entity_types
  }
}

# Usage Instructions
output "usage_instructions" {
  description = "Instructions for using the PII redaction infrastructure"
  value = <<-EOT
    
    ═══════════════════════════════════════════════════════════════════════════
    PII REDACTION WITH API GATEWAY - USAGE INSTRUCTIONS
    ═══════════════════════════════════════════════════════════════════════════
    
    NOTE: S3 Object Lambda is not available in your AWS account.
    Using API Gateway + Lambda instead for PII redaction.
    
    Custom Domain: https://${aws_api_gateway_domain_name.pii_api.domain_name}
    Default URL: ${aws_api_gateway_stage.prod.invoke_url}
    
    1. Upload a file with PII data to the S3 bucket:
       aws s3 cp sample.txt s3://${aws_s3_bucket.pii_data_bucket.id}/
    
    2. Retrieve the file WITHOUT redaction (direct from bucket):
       aws s3api get-object --bucket ${aws_s3_bucket.pii_data_bucket.id} --key sample.txt output.txt
    
    3. Retrieve the file WITH redaction (through custom domain):
       curl -o redacted.txt "https://${aws_api_gateway_domain_name.pii_api.domain_name}/${aws_s3_bucket.pii_data_bucket.id}/sample.txt" \
         --aws-sigv4 "aws:amz:${data.aws_region.current.name}:execute-api" \
         --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY"
    
    OR use Python with boto3 and requests-aws4auth:
       
       import boto3
       import requests
       from requests_aws4auth import AWS4Auth
       
       session = boto3.Session()
       credentials = session.get_credentials()
       auth = AWS4Auth(
           credentials.access_key,
           credentials.secret_key,
           '${data.aws_region.current.name}',
           'execute-api',
           session_token=credentials.token
       )
       
       url = "https://${aws_api_gateway_domain_name.pii_api.domain_name}/${aws_s3_bucket.pii_data_bucket.id}/sample.txt"
       response = requests.get(url, auth=auth)
       print(response.text)
    
    Configuration:
    - Mask Character: ${var.mask_character}
    - Mask Mode: ${var.mask_mode}
    - PII Entity Types: ${var.pii_entity_types}
    
    ═══════════════════════════════════════════════════════════════════════════
  EOT
}

