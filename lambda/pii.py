"""
AWS Lambda Function for PII Redaction using Amazon Comprehend
Integrates with S3 Object Lambda to detect and redact PII in real-time
Supports multiple document formats: PDF, TXT, JSON, CSV, etc.

Based on: https://docs.aws.amazon.com/AmazonS3/latest/userguide/tutorial-s3-object-lambda-redact-pii.html
"""

import boto3
import json
import os
import io
import urllib.request
from typing import Dict, List, Any, Tuple

# PDF processing
try:
    import PyPDF2
    from reportlab.pdfgen import canvas
    from reportlab.lib.pagesizes import letter
    from reportlab.lib.units import inch
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    PDF_SUPPORT = True
except ImportError:
    PDF_SUPPORT = False
    print("Warning: PDF libraries not available. PDF processing disabled.")

# Initialize AWS clients
s3 = boto3.client('s3')
comprehend = boto3.client('comprehend')


def detect_pii_entities(text: str, language_code: str = 'en') -> List[Dict[str, Any]]:
    """
    Use Amazon Comprehend to detect PII entities in text
    
    Args:
        text: The text to analyze for PII
        language_code: Language of the text (default: 'en')
    
    Returns:
        List of PII entities detected by Comprehend
    """
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
    """
    Redact PII from text using Amazon Comprehend detection
    
    Args:
        text: The text to redact
        pii_entity_types: List of PII entity types to redact (or ['ALL'] for all types)
        mask_mode: 'MASK' to use mask character, 'REPLACE_WITH_PII_ENTITY_TYPE' to show entity type
        mask_character: Character to use for masking (default: '*')
    
    Returns:
        Redacted text
    """
    if not text:
        return text
    
    # Detect PII entities using Amazon Comprehend
    entities = detect_pii_entities(text)
    
    if not entities:
        return text
    
    # Sort entities by BeginOffset in descending order to avoid offset shifts during replacement
    entities_sorted = sorted(entities, key=lambda x: x['BeginOffset'], reverse=True)
    
    # Redact each entity
    redacted_text = text
    for entity in entities_sorted:
        entity_type = entity['Type']
        
        # Check if we should redact this entity type
        if 'ALL' in pii_entity_types or entity_type in pii_entity_types:
            begin = entity['BeginOffset']
            end = entity['EndOffset']
            original_text = text[begin:end]
            
            # Determine replacement based on mask mode
            if mask_mode == 'REPLACE_WITH_PII_ENTITY_TYPE':
                replacement = f'[{entity_type}]'
            else:  # MASK mode (default)
                replacement = mask_character * len(original_text)
            
            # Replace the PII entity
            redacted_text = redacted_text[:begin] + replacement + redacted_text[end:]
    
    return redacted_text


def extract_text_from_pdf(pdf_bytes: bytes) -> str:
    """
    Extract text content from a PDF file
    
    Args:
        pdf_bytes: PDF file content as bytes
    
    Returns:
        Extracted text from all pages
    """
    if not PDF_SUPPORT:
        raise Exception("PDF processing libraries not available")
    
    text_content = []
    pdf_file = io.BytesIO(pdf_bytes)
    
    try:
        pdf_reader = PyPDF2.PdfReader(pdf_file)
        for page in pdf_reader.pages:
            text_content.append(page.extract_text())
        
        return '\n\n--- PAGE BREAK ---\n\n'.join(text_content)
    except Exception as e:
        raise Exception(f"Error extracting text from PDF: {str(e)}")


def create_redacted_pdf(original_text: str, redacted_text: str) -> bytes:
    """
    Create a new PDF with redacted text content
    
    Args:
        original_text: Original extracted text (for reference)
        redacted_text: Redacted text to write to PDF
    
    Returns:
        PDF file content as bytes
    """
    if not PDF_SUPPORT:
        raise Exception("PDF processing libraries not available")
    
    buffer = io.BytesIO()
    
    # Create PDF with reportlab
    pdf = canvas.Canvas(buffer, pagesize=letter)
    width, height = letter
    
    # Set up text formatting
    pdf.setFont("Helvetica", 10)
    
    # Split text by pages (if we had page breaks during extraction)
    pages = redacted_text.split('\n\n--- PAGE BREAK ---\n\n')
    
    for page_text in pages:
        # Write text to PDF page
        text_object = pdf.beginText(0.75 * inch, height - 0.75 * inch)
        text_object.setFont("Helvetica", 10)
        text_object.setTextOrigin(0.75 * inch, height - 0.75 * inch)
        
        # Split into lines and add to PDF
        lines = page_text.split('\n')
        for line in lines:
            # Wrap long lines
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
        pdf.showPage()  # Start new page
    
    pdf.save()
    
    return buffer.getvalue()


def detect_content_type(content: bytes, key: str) -> Tuple[str, str]:
    """
    Detect content type based on file extension and content
    
    Args:
        content: File content as bytes
        key: S3 object key (filename)
    
    Returns:
        Tuple of (format, content_type)
    """
    key_lower = key.lower()
    
    if key_lower.endswith('.pdf'):
        return ('pdf', 'application/pdf')
    elif key_lower.endswith('.json'):
        return ('json', 'application/json')
    elif key_lower.endswith('.csv'):
        return ('csv', 'text/csv')
    elif key_lower.endswith('.txt'):
        return ('txt', 'text/plain')
    else:
        # Default to text
        return ('txt', 'text/plain')


def process_document(content: bytes, format_type: str, pii_entity_types: List[str], 
                     mask_mode: str, mask_character: str) -> Tuple[bytes, str]:
    """
    Process document based on its format
    
    Args:
        content: Document content as bytes
        format_type: Document format (pdf, txt, json, csv)
        pii_entity_types: PII types to redact
        mask_mode: Redaction mode
        mask_character: Character for masking
    
    Returns:
        Tuple of (redacted_content_bytes, content_type)
    """
    if format_type == 'pdf':
        # Extract text from PDF
        original_text = extract_text_from_pdf(content)
        
        # Redact PII
        redacted_text = redact_pii(original_text, pii_entity_types, mask_mode, mask_character)
        
        # Create new PDF with redacted content
        redacted_pdf = create_redacted_pdf(original_text, redacted_text)
        
        return (redacted_pdf, 'application/pdf')
    
    else:
        # Handle text-based formats
        original_text = content.decode('utf-8')
        redacted_text = redact_pii(original_text, pii_entity_types, mask_mode, mask_character)
        
        # Determine content type
        if format_type == 'json':
            content_type = 'application/json'
        elif format_type == 'csv':
            content_type = 'text/csv'
        else:
            content_type = 'text/plain'
        
        return (redacted_text.encode('utf-8'), content_type)


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for S3 Object Lambda
    
    Triggered by S3 Object Lambda Access Point GET requests
    Retrieves object, redacts PII using Amazon Comprehend, and returns redacted content
    """
    print(f"Received event: {json.dumps(event)}")
    
    # Extract S3 Object Lambda context
    object_context = event.get('getObjectContext', {})
    request_route = object_context.get('outputRoute')
    request_token = object_context.get('outputToken')
    input_s3_url = object_context.get('inputS3Url')
    
    # Extract configuration payload (optional parameters)
    user_request = event.get('userRequest', {})
    configuration = event.get('configuration', {})
    payload = configuration.get('payload', '{}')
    
    try:
        # Parse payload configuration
        config = json.loads(payload) if isinstance(payload, str) else payload
        mask_character = config.get('maskCharacter', os.environ.get('MASK_CHARACTER', '*'))
        mask_mode = config.get('maskMode', os.environ.get('MASK_MODE', 'MASK'))
        pii_entity_types_str = config.get('piiEntityTypes', os.environ.get('PII_ENTITY_TYPES', 'ALL'))
        
        # Parse PII entity types (can be comma-separated string or list)
        if isinstance(pii_entity_types_str, str):
            pii_entity_types = [t.strip() for t in pii_entity_types_str.split(',')] if pii_entity_types_str != 'ALL' else ['ALL']
        else:
            pii_entity_types = pii_entity_types_str
        
        print(f"Configuration - MaskMode: {mask_mode}, MaskCharacter: {mask_character}, PII Types: {pii_entity_types}")
        
        # Get S3 object key from user request
        s3_key = user_request.get('url', '').split('/')[-1] if user_request.get('url') else 'unknown'
        
        # Retrieve the original object from S3
        print(f"Fetching object from: {input_s3_url}")
        with urllib.request.urlopen(input_s3_url) as response:
            original_content = response.read()
        
        # Detect content type and format
        format_type, default_content_type = detect_content_type(original_content, s3_key)
        print(f"Detected format: {format_type}, Content type: {default_content_type}")
        
        # Process document based on format
        print(f"Processing {format_type} document (size: {len(original_content)} bytes)")
        redacted_content, content_type = process_document(
            content=original_content,
            format_type=format_type,
            pii_entity_types=pii_entity_types,
            mask_mode=mask_mode,
            mask_character=mask_character
        )
        
        # Write the redacted object back through S3 Object Lambda
        print(f"Returning redacted {format_type} content (size: {len(redacted_content)} bytes)")
        s3.write_get_object_response(
            RequestRoute=request_route,
            RequestToken=request_token,
            Body=redacted_content,
            ContentType=content_type
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps('PII redaction completed successfully')
        }
        
    except Exception as e:
        print(f"Error processing request: {str(e)}")
        # Return error response through S3 Object Lambda
        try:
            s3.write_get_object_response(
                RequestRoute=request_route,
                RequestToken=request_token,
                StatusCode=500,
                ErrorCode='InternalError',
                ErrorMessage=str(e)
            )
        except Exception as write_error:
            print(f"Error writing error response: {str(write_error)}")
        
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
