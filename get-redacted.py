#!/usr/bin/env python3
"""
Simple script to download redacted files from PII API
Handles AWS Signature V4 authentication properly
"""

import boto3
import requests
from requests_aws4auth import AWS4Auth
import sys
import os

# Configuration
API_URL = "https://pii-api.sebekgo.com"
BUCKET = "pii-data-bucket-20260408063957872000000003"
REGION = "us-west-2"

def download_redacted(filename, output_file=None):
    """Download redacted version of file from API"""
    
    # Get AWS credentials
    session = boto3.Session()
    credentials = session.get_credentials()
    
    # Create AWS Signature V4 auth
    auth = AWS4Auth(
        credentials.access_key,
        credentials.secret_key,
        REGION,
        'execute-api',
        session_token=credentials.token
    )
    
    # Build URL
    url = f"{API_URL}/{BUCKET}/{filename}"
    
    print(f"Requesting: {url}")
    print(f"Using credentials for: {session.client('sts').get_caller_identity()['Arn']}")
    
    # Make request
    response = requests.get(url, auth=auth)
    
    if response.status_code == 200:
        # Determine output filename
        if not output_file:
            output_file = f"redacted-{filename}"
        
        # Check if response is JSON (base64 encoded PDF)
        try:
            data = response.json()
            if data.get('isBase64Encoded'):
                import base64
                content = base64.b64decode(data['body'])
                mode = 'wb'
            else:
                content = data.get('body', '')
                mode = 'w'
        except:
            # Plain text response
            content = response.text
            mode = 'w'
        
        # Save file
        with open(output_file, mode) as f:
            f.write(content)
        
        print(f"✅ Success! Redacted file saved to: {output_file}")
        print(f"   Size: {os.path.getsize(output_file)} bytes")
        return True
    else:
        print(f"❌ Error {response.status_code}: {response.text}")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python get-redacted.py <filename> [output_file]")
        print("Example: python get-redacted.py PiiTest.txt")
        print("         python get-redacted.py document.pdf redacted-doc.pdf")
        sys.exit(1)
    
    filename = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    download_redacted(filename, output_file)
