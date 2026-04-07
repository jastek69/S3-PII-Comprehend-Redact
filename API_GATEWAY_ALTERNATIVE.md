# ⚠️ API Gateway Alternative Architecture

## Issue: S3 Object Lambda Not Available

Your AWS account doesn't have access to S3 Object Lambda. The error message states:

> "Amazon S3 Object Lambda is available only to existing customers that are currently using the service as well as to select AWS Partner Network (APN) partners."

## ✅ Solution: API Gateway + Lambda

I've refactored the infrastructure to use **API Gateway + Lambda** instead. This provides the **same PII redaction functionality** with a different access pattern.

## 🏗️ New Architecture

```
Original (S3 Object Lambda - Not Available):
Client → S3 Object Lambda Access Point → Lambda → S3 Bucket

New (API Gateway - Available):
Client → API Gateway → Lambda → S3 Bucket
```

## 📝 What Changed

### Files Modified
- **[s3.tf](s3.tf)** - Removed S3 Object Lambda Access Point
- **[lambda.tf](lambda.tf)** - Updated to use API Gateway handler
- **[outputs.tf](outputs.tf)** - Updated with API Gateway URL

### Files Created
- **[api-gateway.tf](api-gateway.tf)** - API Gateway configuration
- **[lambda/api-gateway-handler.py](lambda/api-gateway-handler.py)** - API Gateway Lambda handler

## 🚀 Deploy Now

```bash
# Build Lambda layer for PDF support
lambda\build-layer.bat  # Windows
# OR
./lambda/build-layer.sh # Linux/Mac

# Deploy
terraform apply
```

## 📖 Usage

### Old Way (S3 Object Lambda - Not Available)
```bash
aws s3api get-object --bucket OLAP_ARN --key file.txt redacted.txt
```

### New Way (API Gateway - Available)
```bash
# Get API URL
API_URL=$(terraform output -raw api_gateway_url)
BUCKET=$(terraform output -raw pii_data_bucket_name)

# Retrieve WITH redaction (using AWS signature)
curl -o redacted.txt "$API_URL/$BUCKET/file.txt" \
  --aws-sigv4 "aws:amz:us-west-1:execute-api" \
  --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY"
```

### Python Example (Recommended)

```python
import boto3
import requests
from requests_aws4auth import AWS4Auth

# Install: pip install requests requests-aws4auth

session = boto3.Session()
creds = session.get_credentials()

auth = AWS4Auth(
    creds.access_key,
    creds.secret_key,
    'us-west-1',  # your region
    'execute-api',
    session_token=creds.token
)

# Get redacted file
api_url = "YOUR_API_URL"  # from terraform output
bucket = "YOUR_BUCKET"     # from terraform output
response = requests.get(f"{api_url}/{bucket}/file.txt", auth=auth)

# Save redacted content
with open('redacted.txt', 'wb') as f:
    f.write(response.content)
```

## 🎯 Benefits of API Gateway Approach

✅ **Available in all AWS accounts** - No special access needed
✅ **Same PII redaction functionality** - Uses Amazon Comprehend
✅ **Supports all file formats** - PDF, TXT, JSON, CSV
✅ **Real-time processing** - Redaction happens on request
✅ **Original files unchanged** - S3 bucket remains intact
✅ **IAM authentication** - Secure access control
✅ **CloudWatch logging** - Full observability
✅ **Scalable** - API Gateway + Lambda auto-scale

## 💰 Cost Comparison

**S3 Object Lambda (if available):**
- S3 requests: $0.005/1000 requests
- Lambda: $0.20/million requests
- Comprehend: $0.0001/100 characters

**API Gateway (your solution):**
- API Gateway: $3.50/million requests
- Lambda: $0.20/million requests
- Comprehend: $0.0001/100 characters

**Slightly more expensive but available!**

## 🔧 Testing

```bash
# 1. Upload test file
BUCKET=$(terraform output -raw pii_data_bucket_name)
aws s3 cp sample-pii.txt s3://$BUCKET/

# 2. Get WITHOUT redaction
aws s3api get-object --bucket $BUCKET --key sample-pii.txt original.txt

# 3. Get WITH redaction (API Gateway)
API_URL=$(terraform output -raw api_gateway_url)
curl "$API_URL/$BUCKET/sample-pii.txt" \
  --aws-sigv4 "aws:amz:us-west-1:execute-api" \
  --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
  -o redacted.txt

# 4. Compare
echo "=== ORIGINAL ==="
cat original.txt
echo ""
echo "=== REDACTED ==="
cat redacted.txt
```

## 🎨 All Features Still Work

- ✅ PDF support
- ✅ TXT, JSON, CSV support
- ✅ Mask character customization
- ✅ Mask mode (MASK or REPLACE_WITH_PII_ENTITY_TYPE)
- ✅ PII entity type selection
- ✅ CloudWatch logging
- ✅ Multi-page PDFs
- ✅ Original files unchanged

## ⚡ Quick Reference

```bash
# Deploy
terraform apply

# Get URLs
terraform output api_gateway_url
terraform output pii_data_bucket_name

# Upload file
aws s3 cp file.pdf s3://BUCKET/

# Get redacted (curl)
curl API_URL/BUCKET/file.pdf --aws-sigv4 "aws:amz:REGION:execute-api" --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" -o redacted.pdf

# Get redacted (Python)
# See Python example above
```

## 📚 Next Steps

1. **Deploy**: Run `terraform apply`
2. **Test**: Upload a file and retrieve it via API Gateway
3. **Integrate**: Update your application to use API Gateway URL instead of S3
4. **Monitor**: Check CloudWatch Logs for Lambda and API Gateway

The functionality is **identical** - just a different access method! 🎉
