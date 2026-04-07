"""
API Gateway Handler for PII Redaction
Alternative to S3 Object Lambda when service is not available

Access pattern:
GET https://api-id.execute-api.region.amazonaws.com/prod/{bucket}/{key}
"""

import boto3
import json
import os
import io
from typing import Dict, List, Any, Tuple
import base64

# PDF processing
try:
    import PyPDF2
    from reportlab.pdfgen import canvas
    from reportlab.lib.pagesizes import letter
    from reportlab.lib.units import inch
    PDF_SUPPORT = True
except ImportError:
    PDF_SUPPORT = False

# Initialize AWS clients
s3 = boto3.client('s3')
# Comprehend may not be available in all regions - use us-east-1 if needed
comprehend = boto3.client('comprehend', region_name=os.environ.get('COMPREHEND_REGION', 'us-east-1'))
textract = boto3.client('textract', region_name=os.environ.get('COMPREHEND_REGION', 'us-east-1'))


def detect_pii_entities(text: str, language_code: str = 'en') -> List[Dict[str, Any]]:
    """Use Amazon Comprehend to detect PII entities in text"""
    try:
        response = comprehend.detect_pii_entities(
            Text=text,
            LanguageCode=language_code
        )
        return response.get('Entities', [])
    except Exception as e:
        print(f"Error detecting PII entities: {str(e)}")
        return []


def redact_pii(text: str, pii_entity_types: List[str], mask_mode: str = 'MASK', mask_character: str = '*') -> str:
    """Redact PII from text using Amazon Comprehend detection"""
    if not text:
        return text
    
    entities = detect_pii_entities(text)
    if not entities:
        return text
    
    entities_sorted = sorted(entities, key=lambda x: x['BeginOffset'], reverse=True)
    redacted_text = text
    
    for entity in entities_sorted:
        entity_type = entity['Type']
        
        if 'ALL' in pii_entity_types or entity_type in pii_entity_types:
            begin = entity['BeginOffset']
            end = entity['EndOffset']
            original_text = text[begin:end]
            
            if mask_mode == 'REPLACE_WITH_PII_ENTITY_TYPE':
                replacement = f'[{entity_type}]'
            else:
                replacement = mask_character * len(original_text)
            
            redacted_text = redacted_text[:begin] + replacement + redacted_text[end:]
    
    return redacted_text


def is_scanned_pdf(pdf_bytes: bytes) -> bool:
    """Check if PDF is image-based (scanned) by checking if PyPDF2 can extract text"""
    if not PDF_SUPPORT:
        return False
    
    try:
        pdf_file = io.BytesIO(pdf_bytes)
        pdf_reader = PyPDF2.PdfReader(pdf_file)
        
        # Sample first few pages to check for text
        sample_pages = min(3, len(pdf_reader.pages))
        total_text = ''
        
        for i in range(sample_pages):
            total_text += pdf_reader.pages[i].extract_text().strip()
        
        # If less than 10 characters extracted, likely scanned/image-based
        return len(total_text) < 10
    except Exception as e:
        print(f"Error checking if PDF is scanned: {str(e)}")
        return False


def extract_text_with_textract(bucket: str, key: str) -> str:
    """Extract text from image-based PDF using Amazon Textract OCR (asynchronous for large files)"""
    import time
    
    try:
        # Start asynchronous document text detection
        response = textract.start_document_text_detection(
            DocumentLocation={
                'S3Object': {
                    'Bucket': bucket,
                    'Name': key
                }
            }
        )
        
        job_id = response['JobId']
        print(f"Started Textract job {job_id}, polling for results...")
        
        # Poll for completion (max 10 minutes)
        max_attempts = 120
        attempt = 0
        
        while attempt < max_attempts:
            time.sleep(5)  # Wait 5 seconds between polls
            
            result = textract.get_document_text_detection(JobId=job_id)
            status = result['JobStatus']
            
            if status == 'SUCCEEDED':
                print(f"Textract job completed successfully after {attempt * 5} seconds")
                
                # Extract text from all pages
                text_content = []
                for block in result.get('Blocks', []):
                    if block['BlockType'] == 'LINE':
                        text_content.append(block.get('Text', ''))
                
                # Handle multi-page results with pagination
                next_token = result.get('NextToken')
                while next_token:
                    result = textract.get_document_text_detection(
                        JobId=job_id,
                        NextToken=next_token
                    )
                    for block in result.get('Blocks', []):
                        if block['BlockType'] == 'LINE':
                            text_content.append(block.get('Text', ''))
                    next_token = result.get('NextToken')
                
                return '\n'.join(text_content)
            
            elif status == 'FAILED':
                raise Exception(f"Textract job failed: {result.get('StatusMessage', 'Unknown error')}")
            
            attempt += 1
        
        raise Exception("Textract job timed out after 10 minutes")
    
    except Exception as e:
        raise Exception(f"Error extracting text with Textract: {str(e)}")


def extract_text_from_pdf(pdf_bytes: bytes, bucket: str = None, key: str = None) -> str:
    """Extract text content from a PDF file (text-based or scanned)"""
    if not PDF_SUPPORT:
        raise Exception("PDF processing libraries not available")
    
    # Check if PDF is scanned/image-based
    if is_scanned_pdf(pdf_bytes):
        print("Detected scanned PDF, using Textract OCR")
        if not bucket or not key:
            raise Exception("Bucket and key required for Textract OCR")
        return extract_text_with_textract(bucket, key)
    
    # Standard text-based PDF extraction
    print("Detected text-based PDF, using PyPDF2")
    text_content = []
    pdf_file = io.BytesIO(pdf_bytes)
    
    try:
        pdf_reader = PyPDF2.PdfReader(pdf_file)
        for page in pdf_reader.pages:
            text_content.append(page.extract_text())
        return '\n\n--- PAGE BREAK ---\n\n'.join(text_content)
    except Exception as e:
        raise Exception(f"Error extracting text from PDF: {str(e)}")


def create_redacted_pdf(redacted_text: str) -> bytes:
    """Create a new PDF with redacted text content"""
    if not PDF_SUPPORT:
        raise Exception("PDF processing libraries not available")
    
    buffer = io.BytesIO()
    pdf = canvas.Canvas(buffer, pagesize=letter)
    width, height = letter
    pdf.setFont("Helvetica", 10)
    
    pages = redacted_text.split('\n\n--- PAGE BREAK ---\n\n')
    
    for page_text in pages:
        text_object = pdf.beginText(0.75 * inch, height - 0.75 * inch)
        text_object.setFont("Helvetica", 10)
        
        lines = page_text.split('\n')
        for line in lines:
            if len(line) > 80:
                words = line.split(' ')
                current_line = ''
                for word in words:
                    if len(current_line) + len(word) + 1 <= 80:
                        current_line += word + ' '
                    else:
                        text_object.textLine(current_line.strip())
                        current_line = word + ' '
                if current_line:
                    text_object.textLine(current_line.strip())
            else:
                text_object.textLine(line)
        
        pdf.drawText(text_object)
        pdf.showPage()
    
    pdf.save()
    return buffer.getvalue()


def detect_content_type(key: str) -> Tuple[str, str]:
    """Detect content type based on file extension"""
    key_lower = key.lower()
    
    if key_lower.endswith('.pdf'):
        return ('pdf', 'application/pdf')
    elif key_lower.endswith('.json'):
        return ('json', 'application/json')
    elif key_lower.endswith('.csv'):
        return ('csv', 'text/csv')
    else:
        return ('txt', 'text/plain')


def process_document(content: bytes, format_type: str, pii_entity_types: List[str], 
                     mask_mode: str, mask_character: str, bucket: str = None, key: str = None) -> Tuple[bytes, str]:
    """Process document based on its format"""
    if format_type == 'pdf':
        original_text = extract_text_from_pdf(content, bucket, key)
        redacted_text = redact_pii(original_text, pii_entity_types, mask_mode, mask_character)
        redacted_pdf = create_redacted_pdf(redacted_text)
        return (redacted_pdf, 'application/pdf')
    else:
        original_text = content.decode('utf-8')
        redacted_text = redact_pii(original_text, pii_entity_types, mask_mode, mask_character)
        
        if format_type == 'json':
            content_type = 'application/json'
        elif format_type == 'csv':
            content_type = 'text/csv'
        else:
            content_type = 'text/plain'
        
        return (redacted_text.encode('utf-8'), content_type)


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    API Gateway handler for PII redaction
    
    GET /{bucket}/{key} - Returns redacted version of S3 object
    """
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Extract bucket and key from path parameters
        path_params = event.get('pathParameters', {})
        bucket = path_params.get('bucket')
        key = path_params.get('key')
        
        if not bucket or not key:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing bucket or key parameter'}),
                'headers': {'Content-Type': 'application/json'}
            }
        
        # Get configuration from environment variables
        mask_character = os.environ.get('MASK_CHARACTER', '*')
        mask_mode = os.environ.get('MASK_MODE', 'MASK')
        pii_entity_types_str = os.environ.get('PII_ENTITY_TYPES', 'ALL')
        
        pii_entity_types = [t.strip() for t in pii_entity_types_str.split(',')] if pii_entity_types_str != 'ALL' else ['ALL']
        
        print(f"Fetching s3://{bucket}/{key}")
        print(f"Config - MaskMode: {mask_mode}, MaskChar: {mask_character}, PII Types: {pii_entity_types}")
        
        # Get object from S3
        s3_response = s3.get_object(Bucket=bucket, Key=key)
        original_content = s3_response['Body'].read()
        
        # Detect format and process
        format_type, default_content_type = detect_content_type(key)
        print(f"Processing {format_type} document ({len(original_content)} bytes)")
        
        redacted_content, content_type = process_document(
            content=original_content,
            format_type=format_type,
            pii_entity_types=pii_entity_types,
            mask_mode=mask_mode,
            mask_character=mask_character,
            bucket=bucket,
            key=key
        )
        
        # Return response
        # For binary content (PDF), base64 encode
        if format_type == 'pdf':
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': content_type,
                    'Content-Disposition': f'inline; filename="{key.split("/")[-1]}"'
                },
                'body': base64.b64encode(redacted_content).decode('utf-8'),
                'isBase64Encoded': True
            }
        else:
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': content_type
                },
                'body': redacted_content.decode('utf-8')
            }
        
    except s3.exceptions.NoSuchKey:
        return {
            'statusCode': 404,
            'body': json.dumps({'error': 'Object not found'}),
            'headers': {'Content-Type': 'application/json'}
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)}),
            'headers': {'Content-Type': 'application/json'}
        }
