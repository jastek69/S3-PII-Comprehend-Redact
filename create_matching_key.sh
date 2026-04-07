#!/usr/bin/env bash
# Generate SSH key pair locally and import to AWS

KEY_NAME="piiKP"
REGION="us-west-2"
PEM_FILE="piiKP.pem"
PUB_FILE="piiKP.pem.pub"

echo "=== Generating local SSH key pair ==="
# Remove old keys
rm -f "$PEM_FILE" "$PUB_FILE"

# Generate new key pair locally
ssh-keygen -t rsa -b 2048 -f "$PEM_FILE" -N "" -C "piiKP-key"

# Set correct permissions
chmod 400 "$PEM_FILE"

echo ""
echo "=== Deleting AWS key pair (if exists) ==="
aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$REGION" 2>/dev/null || true

echo ""
echo "=== Importing public key to AWS ==="
aws ec2 import-key-pair \
  --key-name "$KEY_NAME" \
  --public-key-material "fileb://$PUB_FILE" \
  --region "$REGION"

echo ""
echo "=== Verification ==="
echo "Local key fingerprint:"
ssh-keygen -l -E md5 -f "$PEM_FILE"

echo ""
echo "AWS key fingerprint:"
aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" --query 'KeyPairs[0].KeyFingerprint' --output text

echo ""
echo "✓ Key pair created and imported successfully"
echo "✓ Private key: $PEM_FILE"
echo "✓ Public key: $PUB_FILE"
