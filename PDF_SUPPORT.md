# 📄 PDF Support Guide

## Overview

The PII redaction Lambda function now supports PDF files alongside TXT, JSON, and CSV formats. When a PDF is requested through the S3 Object Lambda Access Point, the function:

1. Extracts text from all pages
2. Sends text to Amazon Comprehend for PII detection
3. Redacts detected PII entities
4. Regenerates a new PDF with redacted content
5. Returns the redacted PDF to the requester

**Important**: Original PDF files in S3 remain unchanged.

## Setup Requirements

### Build the Lambda Layer

Before deploying, you must build a Lambda Layer containing PDF processing libraries:

**On Windows:**
```batch
cd lambda
build-layer.bat
```

**On Linux/Mac:**
```bash
cd lambda
chmod +x build-layer.sh
./build-layer.sh
```

This creates `lambda/pdf-layer.zip` containing:
- PyPDF2 (for PDF reading)
- reportlab (for PDF generation)

### Deploy with Terraform

After building the layer:
```bash
terraform apply
```

Terraform will automatically attach the layer to your Lambda function if `pdf-layer.zip` exists.

## Creating Test PDFs

### Option 1: Use the Python Script

```bash
pip install reportlab
python create-sample-pdf.py
```

This creates `sample-pii.pdf` with various PII types.

### Option 2: Manual Creation

Create a PDF using Word, Google Docs, or any PDF editor with content like:

```
Customer Support Ticket #12345

Name: John Smith
Email: john.smith@example.com
Phone: 555-123-4567
SSN: 123-45-6789
Address: 123 Main Street, New York, NY 10001
Credit Card: 4532-1234-5678-9010

Issue: Customer reported unauthorized charges.
```

## Testing PDF Redaction

### Upload PDF to S3

```bash
BUCKET=$(terraform output -raw pii_data_bucket_name)
aws s3 cp sample-pii.pdf s3://$BUCKET/
```

### Retrieve Original PDF (No Redaction)

```bash
aws s3api get-object --bucket $BUCKET --key sample-pii.pdf original.pdf
```

### Retrieve Redacted PDF (Through Object Lambda)

```bash
OLAP_ARN=$(terraform output -raw object_lambda_access_point_arn)
aws s3api get-object --bucket $OLAP_ARN --key sample-pii.pdf redacted.pdf
```

### Compare PDFs

Open both PDFs side-by-side:
- **original.pdf**: Shows all PII data clearly
- **redacted.pdf**: PII replaced with asterisks or entity type labels

## Configuration Options

### Mask Mode: MASK (Default)

```hcl
mask_mode = "MASK"
mask_character = "*"
```

**Result in PDF:**
```
Name: **********
Email: *************************
Phone: ************
SSN: ***********
```

### Mask Mode: Entity Type Labels

```hcl
mask_mode = "REPLACE_WITH_PII_ENTITY_TYPE"
```

**Result in PDF:**
```
Name: [NAME]
Email: [EMAIL]
Phone: [PHONE]
SSN: [SSN]
```

### Specific PII Types Only

```hcl
pii_entity_types = "EMAIL,PHONE,SSN,CREDIT_DEBIT_NUMBER"
```

Only redacts the specified types; other PII remains visible.

## Performance Considerations

### Lambda Configuration

PDF processing requires more resources than plain text:

```hcl
lambda_timeout     = 300   # 5 minutes (default)
lambda_memory_size = 1024  # 1GB RAM (default)
```

**Adjust for your needs:**
- Small PDFs (1-5 pages): 512MB, 60s timeout
- Medium PDFs (5-20 pages): 1024MB, 180s timeout
- Large PDFs (20+ pages): 2048MB, 300s timeout

### Cost Implications

PDF processing is more expensive than text files:

**Example: 1000 PDFs/month, 10 pages each, 5KB/page**
- Lambda compute: ~$2.50/month
- Comprehend: ~$15/month (50K characters per PDF)
- S3 requests: ~$0.50/month
- **Total**: ~$18/month

Compare with text files: ~$3/month for same volume.

## Limitations

### Current PDF Features
✅ Text extraction from standard PDFs
✅ Multi-page support
✅ Basic formatting preservation
✅ PII detection and redaction

### Not Supported Yet
❌ Image-based PDFs (scanned documents) - requires OCR
❌ Complex layouts (tables, columns) - may lose formatting
❌ Embedded images - not processed
❌ Forms and interactive elements
❌ Digital signatures
❌ Encryption/password-protected PDFs

### Workarounds

**For scanned PDFs:**
1. Use Amazon Textract for OCR first
2. Extract text to temporary file
3. Apply PII redaction
4. Regenerate PDF

**For complex layouts:**
Consider processing as text and notifying users that formatting may change.

## Troubleshooting

### Layer Not Found Error

**Error:** `Unable to import module 'pii': No module named 'PyPDF2'`

**Solution:** Build the Lambda layer:
```bash
cd lambda
./build-layer.sh  # or build-layer.bat on Windows
terraform apply
```

### PDF Extraction Errors

**Error:** `Error extracting text from PDF`

**Causes:**
- Encrypted/password-protected PDF
- Scanned images without OCR
- Corrupted PDF file

**Solution:**
- Remove PDF encryption
- Use OCR if scanned
- Verify PDF is valid: `pdfinfo sample.pdf`

### Timeout Errors

**Error:** `Task timed out after 60.00 seconds`

**Solution:** Increase Lambda timeout in [variables.tf](variables.tf):
```hcl
variable "lambda_timeout" {
  default = 300  # Increase to 5 minutes
}
```

### Out of Memory Errors

**Error:** `Runtime.OutOfMemory`

**Solution:** Increase Lambda memory:
```hcl
variable "lambda_memory_size" {
  default = 2048  # Increase to 2GB
}
```

## Advanced: Custom PDF Formatting

To customize the output PDF appearance, edit `create_redacted_pdf()` in [lambda/pii.py](lambda/pii.py):

```python
# Change font
pdf.setFont("Courier", 10)  # Monospace font

# Change page size
from reportlab.lib.pagesizes import A4
pdf = canvas.Canvas(buffer, pagesize=A4)

# Add header/footer
pdf.drawString(inch, height - 0.5*inch, "REDACTED - CONFIDENTIAL")
```

## Best Practices

1. **Test with sample data first** - Don't use production PDFs initially
2. **Monitor Lambda metrics** - Watch execution time and memory usage
3. **Set appropriate timeouts** - Based on your PDF sizes
4. **Cache frequently accessed PDFs** - Use CloudFront if accessing often
5. **Log everything** - Enable CloudWatch Logs for debugging
6. **Validate redaction** - Always verify PII is properly masked

## Cost Optimization

- **Batch processing**: Process multiple pages in single invocation
- **Conditional redaction**: Only process PDFs that need redaction
- **Smart caching**: Cache redacted PDFs for repeated access
- **Optimize memory**: Use just enough RAM for your PDF sizes
- **Lifecycle policies**: Archive old redacted PDFs to Glacier

## Additional Resources

- [PyPDF2 Documentation](https://pypdf2.readthedocs.io/)
- [ReportLab User Guide](https://www.reportlab.com/docs/reportlab-userguide.pdf)
- [AWS Lambda Layers](https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html)
- [Amazon Comprehend PII Detection](https://docs.aws.amazon.com/comprehend/latest/dg/how-pii.html)
