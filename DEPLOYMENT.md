# 🚀 Deployment and Testing Guide

## Prerequisites

Ensure you have the following AWS managed policies attached to your IAM user:
- `AmazonS3FullAccess`
- `AWSLambda_FullAccess`
- `IAMFullAccess` (for creating roles and policies)
- Permissions to use Amazon Comprehend

**Additional Requirements for PDF Support:**
- Python 3.12 installed locally
- pip package manager

## Step 0: Build Lambda Layer for PDF Support

The Lambda function requires additional libraries for PDF processing. Build the Lambda layer first:

### On Linux/Mac:
```bash
chmod +x lambda/build-layer.sh
./lambda/build-layer.sh
```

### On Windows:
```batch
lambda\build-layer.bat
```

This will create `lambda/pdf-layer.zip` containing PyPDF2 and reportlab libraries.

**Note:** If you skip this step, the Lambda function will still work for TXT, JSON, and CSV files, but PDF processing will be disabled.

## Step 1: Initialize Terraform

```bash
terraform init
```

## Step 2: Review the Plan

```bash
terraform plan
```

## Step 3: Deploy the Infrastructure

```bash
terraform apply
```

Review the changes and type `yes` to confirm.

## Step 4: Test PII Redaction with Different File Types

### 4.1 Create test files with PII data

**TXT file (sample-pii.txt):**
```text
Customer Support Ticket #12345

Name: John Smith
Email: john.smith@example.com
Phone: 555-123-4567
SSN: 123-45-6789
Address: 123 Main Street, New York, NY 10001
Credit Card: 4532-1234-5678-9010

Issue: Customer reported unauthorized charges on their account.
```

**PDF file:** Create a PDF with similar content using any PDF editor or Word processor.

### 4.2 Upload test files to S3 bucket

```bash
# Get the bucket name from Terraform output
BUCKET_NAME=$(terraform output -raw pii_data_bucket_name)

# Upload test files
aws s3 cp sample-pii.txt s3://$BUCKET_NAME/sample-pii.txt
aws s3 cp sample-pii.pdf s3://$BUCKET_NAME/sample-pii.pdf
```

### 4.3 Test TXT file redaction

```bash
# Retrieve WITHOUT redaction (direct bucket access)
aws s3api get-object --bucket $BUCKET_NAME --key sample-pii.txt original.txt
cat original.txt

# Retrieve WITH redaction (Object Lambda Access Point)
OLAP_ARN=$(terraform output -raw object_lambda_access_point_arn)
aws s3api get-object --bucket $OLAP_ARN --key sample-pii.txt redacted.txt
cat redacted.txt
```

### 4.4 Test PDF file redaction

```bash
# Retrieve WITHOUT redaction
aws s3api get-object --bucket $BUCKET_NAME --key sample-pii.pdf original.pdf

# Retrieve WITH redaction (PDF will be regenerated with redacted content)
aws s3api get-object --bucket $OLAP_ARN --key sample-pii.pdf redacted.pdf

# Open both PDFs to compare
# Windows: start original.pdf && start redacted.pdf
# Mac: open original.pdf && open redacted.pdf
# Linux: xdg-open original.pdf && xdg-open redacted.pdf
```

**Expected results:**
- Original PDF: Full PII data visible
- Redacted PDF: PII replaced with asterisks or entity type labels

### 4.5 Compare the results

```bash
echo "=== ORIGINAL TXT (No Redaction) ==="
cat original.txt
echo ""
echo "=== REDACTED TXT (Through Object Lambda) ==="
cat redacted.txt
```

## Supported File Formats

The Lambda function automatically detects and processes:

- **PDF (.pdf)** - Extracts text, redacts PII, regenerates PDF
- **Text (.txt)** - Plain text redaction
- **JSON (.json)** - Preserves JSON structure while redacting values
- **CSV (.csv)** - Redacts PII in CSV cells

## Configuration Options

You can customize the redaction behavior by modifying [variables.tf](variables.tf):

```hcl
# Change the mask character
variable "mask_character" {
  default = "#"  # Change from * to #
}

# Change the mask mode
variable "mask_mode" {
  default = "REPLACE_WITH_PII_ENTITY_TYPE"  # Show entity type instead of masking
}

# Redact specific PII types only
variable "pii_entity_types" {
  default = "EMAIL,PHONE,SSN,CREDIT_DEBIT_NUMBER"  # Only these types
}
```

After changing variables, run:
```bash
terraform apply
```

## Monitoring and Logs

Check Lambda execution logs:
```bash
aws logs tail "/aws/lambda/pii-redaction-lambda" --follow
```

## Cost Optimization

- Lambda invocations are billed per request
- Amazon Comprehend charges per 100 characters analyzed
- Consider implementing caching for frequently accessed objects
- Set appropriate S3 lifecycle policies for old data

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note:** If `force_destroy = false` in variables.tf, you'll need to manually empty the S3 buckets before destroying.

## Troubleshooting

### Lambda Timeout Errors
Increase `lambda_timeout` in [variables.tf](variables.tf):
```hcl
variable "lambda_timeout" {
  default = 300  # Increase to 5 minutes
}
```

### Comprehend Throttling
Amazon Comprehend has rate limits. Consider:
- Adding retry logic with exponential backoff
- Requesting a limit increase through AWS Support
- Implementing request batching

### Access Denied Errors
Ensure the Lambda execution role has:
- `comprehend:DetectPiiEntities` permission
- `s3-object-lambda:WriteGetObjectResponse` permission
- Access to the S3 bucket

## Additional Resources

- [AWS Documentation: S3 Object Lambda](https://docs.aws.amazon.com/AmazonS3/latest/userguide/transforming-objects.html)
- [Amazon Comprehend PII Detection](https://docs.aws.amazon.com/comprehend/latest/dg/how-pii.html)
- [Supported PII Entity Types](https://docs.aws.amazon.com/comprehend/latest/dg/how-pii.html#how-pii-types)
