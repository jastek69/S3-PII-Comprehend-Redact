# Architecture Diagram

## PII Redaction Flow with S3 Object Lambda

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          CLIENT APPLICATION                              │
│                     (Analytics, Reporting, etc.)                         │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ S3 GET Request
                                 │ (through Object Lambda Access Point)
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              S3 OBJECT LAMBDA ACCESS POINT                               │
│                  arn:aws:s3-object-lambda:...                            │
│                                                                           │
│  Configuration:                                                           │
│  - Supporting Access Point: Standard S3 Access Point                     │
│  - Transformation: GetObject → Lambda Function                           │
│  - Payload: {maskMode, maskCharacter, piiEntityTypes}                   │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ Invokes Lambda
                                 │ with S3 URL
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    LAMBDA FUNCTION (pii.py)                              │
│                Runtime: Python 3.12, Handler: pii.lambda_handler         │
│                                                                           │
│  Steps:                                                                   │
│  1. Receives event with inputS3Url and outputRoute/Token                │
│  2. Fetches original object from S3  ────────────┐                      │
│  3. Calls Amazon Comprehend for PII detection    │                      │
│  4. Redacts detected PII entities                │                      │
│  5. Writes redacted response back                │                      │
│                                                   │                      │
│  IAM Permissions:                                 │                      │
│  - comprehend:DetectPiiEntities                   │                      │
│  - s3:GetObject                                   │                      │
│  - s3-object-lambda:WriteGetObjectResponse        │                      │
│  - logs:CreateLogGroup, CreateLogStream, PutEvents│                      │
└────────────────┬──────────────────────────────────┼─────────────────────┘
                 │                                   │
                 │ Detect PII                        │ Fetch Object
                 ▼                                   ▼
┌────────────────────────────────┐  ┌──────────────────────────────────────┐
│   AMAZON COMPREHEND            │  │  STANDARD S3 ACCESS POINT            │
│                                │  │  (Supporting Access Point)            │
│  API: DetectPiiEntities        │  │                                      │
│                                │  └─────────────────┬────────────────────┘
│  Returns:                      │                    │
│  - Entity Type (EMAIL, SSN..)  │                    │ Access Object
│  - Begin/End Offset            │                    │
│  - Confidence Score            │                    ▼
│                                │  ┌──────────────────────────────────────┐
│  Supported PII Types:          │  │       S3 BUCKET (Original Data)      │
│  - NAME, ADDRESS, EMAIL        │  │                                      │
│  - PHONE, SSN                  │  │  - Block All Public Access: ✓        │
│  - CREDIT_DEBIT_NUMBER         │  │  - Versioning: Enabled               │
│  - DRIVER_ID, PASSPORT_NUMBER  │  │  - Encryption: AES256                │
│  - BANK_ACCOUNT_NUMBER         │  │  - Contains: Unredacted PII data     │
│  - IP_ADDRESS, MAC_ADDRESS     │  │                                      │
│  - And 20+ more types          │  │  Objects remain UNCHANGED            │
│                                │  │                                      │
└────────────────────────────────┘  └──────────────────────────────────────┘

RESPONSE FLOW:
══════════════
Lambda writes redacted content using WriteGetObjectResponse
    ↓
S3 Object Lambda Access Point returns redacted data
    ↓
Client receives REDACTED content (Original file unchanged)


EXAMPLE TRANSFORMATION:
═══════════════════════
Original Content:
-----------------
Name: John Smith
Email: john.smith@example.com
Phone: 555-123-4567
SSN: 123-45-6789

Redacted Content (MASK mode):
------------------------------
Name: **********
Email: *************************
Phone: ************
SSN: ***********

Redacted Content (REPLACE_WITH_PII_ENTITY_TYPE mode):
------------------------------------------------------
Name: [NAME]
Email: [EMAIL]
Phone: [PHONE]
SSN: [SSN]
```

## Key Components

### 1. S3 Bucket (pii-data-bucket)
- Stores original data with PII
- All public access blocked
- Encryption at rest enabled
- Original files never modified

### 2. Standard S3 Access Point
- Acts as supporting access point for Object Lambda
- Provides access to original S3 bucket
- Same security settings as bucket

### 3. S3 Object Lambda Access Point
- Intercepts GetObject requests
- Invokes Lambda function for transformation
- Returns redacted content to client
- Configurable per-request payload

### 4. Lambda Function
- Python 3.12 runtime
- Integrates with Amazon Comprehend
- Detects and redacts PII in real-time
- Supports multiple redaction modes

### 5. Amazon Comprehend
- ML-powered PII detection
- Supports 25+ PII entity types
- Language-aware (en, es, fr, de, it, pt, ar, hi, ja, ko, zh, zh-TW)
- Pay-per-use pricing

### 6. IAM Roles & Policies
- Lambda execution role with least privilege
- Comprehend API access
- S3 Object Lambda write permissions
- CloudWatch Logs access

## Security Best Practices

✓ All public access blocked on S3 bucket
✓ IAM roles follow principle of least privilege
✓ Data encrypted at rest (AES256)
✓ Data encrypted in transit (TLS)
✓ CloudWatch logging enabled
✓ Original data never exposed through Object Lambda
✓ No PII stored in Lambda environment or logs

## Cost Optimization

- **S3 Storage**: Standard pricing for original data
- **Lambda**: Pay per invocation + compute time
- **Comprehend**: $0.0001 per unit (100 characters of text)
- **CloudWatch Logs**: Standard pricing
- **Data Transfer**: Standard S3 pricing

**Optimization Tips:**
- Implement caching for frequently accessed objects
- Use S3 Intelligent-Tiering for long-term storage
- Set appropriate Lambda memory (512MB default)
- Consider batching small files

## Scalability

- **Lambda**: Scales automatically up to account limits
- **Comprehend**: Throttle limits apply (can request increases)
- **S3 Object Lambda**: No explicit limits
- **Recommended**: Implement exponential backoff for Comprehend API calls
