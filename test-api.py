import boto3
import requests
from requests_aws4auth import AWS4Auth
import subprocess

session = boto3.Session()
creds = session.get_credentials()

auth = AWS4Auth(
    creds.access_key,
    creds.secret_key,
    'us-west-2',
    'execute-api',
    session_token=creds.token
)

# Get bucket name from terraform
bucket = subprocess.check_output(['terraform', 'output', '-raw', 'pii_data_bucket_name']).decode().strip()
url = f"https://pii-api.sebekgo.com/{bucket}/test-pii-data.txt"

print(f"Testing PII Redaction API")
print(f"URL: {url}")
print(f"Fetching with AWS Signature v4 authentication...")
response = requests.get(url, auth=auth)
print(f"\nStatus: {response.status_code}")
print(f"\n=== REDACTED CONTENT ===")
print(response.text)
print("=== END ===")

