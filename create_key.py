#!/usr/bin/env python3
import boto3
import os

ec2 = boto3.client('ec2', region_name='us-west-2')

# Delete existing key
try:
    ec2.delete_key_pair(KeyName='piiKP')
    print("Deleted existing key pair")
except:
    pass

# Create new key
response = ec2.create_key_pair(KeyName='piiKP')

# Save key material
with open('piiKP.pem', 'w', newline='') as f:
    f.write(response['KeyMaterial'])

# Set permissions (Windows compatible)
os.chmod('piiKP.pem', 0o400)

print("✓ Key created and saved to piiKP.pem")
print(f"✓ AWS KeyPairId: {response['KeyPairId']}")
