import boto3
import json

lambda_client = boto3.client('lambda', region_name='us-west-2')

# Get bucket name from terraform output
import subprocess
bucket_name = subprocess.check_output(['terraform', 'output', '-raw', 'pii_data_bucket_name']).decode().strip()

# Test event mimicking API Gateway
test_event = {
    'pathParameters': {
        'bucket': bucket_name,
        'key': 'test-pii-data.txt'
    }
}

print(f"Testing PII redaction with bucket: {bucket_name}")
print("Invoking Lambda function...")
response = lambda_client.invoke(
    FunctionName='pii-redaction-lambda',
    InvocationType='RequestResponse',
    LogType='Tail',  # Get logs
    Payload=json.dumps(test_event)
)

# Read response
result = json.loads(response['Payload'].read())
print("\nLambda Response:")
print(json.dumps(result, indent=2))

if result.get('statusCode') == 200:
    print("\n=== REDACTED CONTENT ===")
    print(result.get('body', ''))
    print("=== END ===")

# Check logs in response
if 'LogResult' in response:
    import base64
    logs = base64.b64decode(response['LogResult']).decode('utf-8')
    print("\n=== Lambda Logs ===")
    print(logs)
