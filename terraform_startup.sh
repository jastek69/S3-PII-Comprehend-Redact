#!/usr/bin/env bash
# PII Redaction with API Gateway + Lambda + Comprehend
# Deployment script for S3 PII redaction infrastructure
# Region: us-west-2 (Comprehend available)
# 
# Usage:
#   Local:   ./terraform_startup.sh
#   Jenkins: Configure as Pipeline/Freestyle project with AWS credentials
###############################################################################################################

set -euo pipefail
trap 'echo "ERROR on line $LINENO"; exit 1' ERR

# Configuration
LAYER_WAIT_TIME=180  # Time to wait for EC2 user-data to build Lambda layer
REGION="us-west-2"
# Use piiKP.pem (AWS console download filename)
SSH_KEY="${SSH_KEY_PATH:-$(pwd)/piiKP.pem}"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=30"

# Jenkins-friendly: disable host key checking for automated deployments
export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

echo "========================================="
echo "PII Redaction Infrastructure Deployment"
echo "Region: $REGION"
echo "Environment: ${BUILD_NUMBER:-local}"
echo "========================================="

# Stage 0: Create SSH key pair for EC2
echo ""
echo "=== Stage 0: Creating SSH key pair ==="
if [ -f "./create_matching_key.sh" ]; then
    ./create_matching_key.sh
    echo "✓ SSH key pair created and imported to AWS"
else
    echo "⚠ Warning: create_matching_key.sh not found, skipping key creation"
fi

# Stage 1: Initial deployment (without Lambda layer)
echo ""
echo "=== Stage 1: Deploying infrastructure (S3, API Gateway, Lambda, EC2) ==="
terraform init -reconfigure
terraform validate
terraform plan -out=pii-initial.tfplan
terraform apply -auto-approve pii-initial.tfplan

# Get EC2 IP for layer download
EC2_IP=$(terraform output -raw pii_ec2_public_ip)
echo ""
echo "EC2 instance launched at: $EC2_IP"
echo "User-data is building Lambda layer automatically..."

# Stage 2: Wait for Lambda layer to be built on EC2
echo ""
echo "=== Stage 2: Waiting ${LAYER_WAIT_TIME}s for Lambda layer build to complete ==="
echo "The EC2 instance is running user-data which:"
echo "  1. Installs Python 3 + pip"
echo "  2. Builds pdf-layer.zip with PyPDF2 and reportlab"
echo "  3. Validates the layer"
echo "  4. Creates test files"
sleep "$LAYER_WAIT_TIME"

# Stage 3: Download Lambda layer from EC2
echo ""
echo "=== Stage 3: Downloading Lambda layer from EC2 ==="
mkdir -p lambda

# Verify SSH key exists and has correct permissions
if [ ! -f "$SSH_KEY" ]; then
  echo "❌ SSH key not found: $SSH_KEY"
  exit 1
fi

echo "Using SSH key: $SSH_KEY"
echo "Downloading from ec2-user@$EC2_IP:/home/ec2-user/pdf-layer.zip"

# Test SSH connection first
echo "Testing SSH connection..."
ssh -i "$SSH_KEY" $SSH_OPTS ec2-user@$EC2_IP 'echo "✅ SSH connection successful"' || {
  echo "❌ SSH connection failed. Check key and security group."
  exit 1
}

# Download layer
scp -i "$SSH_KEY" $SSH_OPTS ec2-user@$EC2_IP:/home/ec2-user/pdf-layer.zip lambda/ || {
  echo "❌ Failed to download layer. Retrying in 30s..."
  sleep 30
  scp -i "$SSH_KEY" $SSH_OPTS ec2-user@$EC2_IP:/home/ec2-user/pdf-layer.zip lambda/ || {
    echo "❌ Still failed. Manual intervention required:"
    echo "   ssh -i $SSH_KEY ec2-user@$EC2_IP 'ls -lh /home/ec2-user/pdf-layer.zip'"
    exit 1
  }
}

# Verify layer was downloaded
if [[ -f "lambda/pdf-layer.zip" ]]; then
  LAYER_SIZE=$(du -h lambda/pdf-layer.zip | cut -f1)
  echo "✅ Lambda layer downloaded: $LAYER_SIZE"
else
  echo "❌ Layer file not found at lambda/pdf-layer.zip"
  exit 1
fi

# Stage 4: Redeploy with Lambda layer
echo ""
echo "=== Stage 4: Redeploying Lambda with PDF support layer ==="
terraform plan -out=pii-with-layer.tfplan
terraform apply -auto-approve pii-with-layer.tfplan

# Stage 5: Upload test file and test PII redaction
echo ""
echo "=== Stage 5: Testing PII redaction ==="
BUCKET=$(terraform output -raw pii_data_bucket_name)

# Create test file
cat > test-pii.txt <<EOF
Customer Information:
Name: John Doe
Email: john.doe@example.com
Phone: (555) 123-4567
SSN: 123-45-6789
Credit Card: 4532-1234-5678-9012
Address: 123 Main Street, San Francisco, CA 94102
EOF

echo "Uploading test file to S3..."
aws s3 cp test-pii.txt s3://$BUCKET/ --region $REGION

# Test with Python script if available
if command -v python3 &> /dev/null && [[ -f "test-lambda.py" ]]; then
  echo ""
  echo "Running Lambda test..."
  python3 test-lambda.py
else
  echo ""
  echo "⚠️  Python test script not available"
  echo "To test manually, run:"
  echo "  python3 test-lambda.py"
fi

# Stage 6: Display outputs
echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
terraform output
echo ""
echo "Quick start:"
echo "  1. Upload file: aws s3 cp myfile.txt s3://$BUCKET/"
echo "  2. Get redacted: $(terraform output -raw pii_ec2_scp_layer_command | cut -d':' -f1) (see outputs for full curl command)"
echo ""
echo "EC2 Helper Scripts (available on EC2):"
echo "  - build-lambda-layer.sh  - Rebuild Lambda layer"
echo "  - test-comprehend.py     - Test Comprehend API"
echo "  - validate-layer.py      - Validate layer contents"
echo "  - create-test-files.py   - Generate PII test files"
echo ""
echo "========================================="
