#!/bin/bash
set -euxo pipefail

# Core packages (Python, Terraform dependencies)
dnf install -y git unzip curl wget python3 python3-pip nginx

# Install Terraform
TERRAFORM_VERSION="1.14.8"
cd /tmp
wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
mv terraform /usr/local/bin/
chmod +x /usr/local/bin/terraform
rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Healthcheck for ALB (port 8081)
mkdir -p /var/www/healthcheck
echo "<html><body>Healthy</body></html>" > /var/www/healthcheck/index.html
cat >/etc/nginx/conf.d/healthcheck.conf <<'EOF'
server {
    listen 8081;
    location / { root /var/www/healthcheck; index index.html; }
}
EOF

# Create Lambda layer build script
cat > /home/ec2-user/build-lambda-layer.sh <<'SCRIPT'
#!/bin/bash
set -e

echo "Building Lambda layer for PII redaction (PyPDF2 + reportlab)..."

# Create requirements.txt
cat > /tmp/requirements.txt <<EOF
PyPDF2==3.0.1
reportlab==4.0.7
EOF

# Build layer
mkdir -p /tmp/lambda-layer/python
pip3 install -r /tmp/requirements.txt -t /tmp/lambda-layer/python/

# Create zip
cd /tmp/lambda-layer
zip -r /home/ec2-user/pdf-layer.zip python/

# Cleanup
cd /home/ec2-user
rm -rf /tmp/lambda-layer /tmp/requirements.txt

echo "✅ Layer created: /home/ec2-user/pdf-layer.zip"
ls -lh /home/ec2-user/pdf-layer.zip

echo ""
echo "To download to your local machine:"
echo "  scp -i piiKP.pem ec2-user@\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):/home/ec2-user/pdf-layer.zip ./lambda/"
SCRIPT

chmod +x /home/ec2-user/build-lambda-layer.sh
chown ec2-user:ec2-user /home/ec2-user/build-lambda-layer.sh

# Create Comprehend test script
cat > /home/ec2-user/test-comprehend.py <<'PYTEST'
#!/usr/bin/env python3
"""Test Amazon Comprehend connectivity and PII detection"""
import boto3
import sys

def test_comprehend():
    comprehend = boto3.client('comprehend', region_name='us-west-2')
    test_text = "John Doe's email is john@example.com and SSN is 123-45-6789"
    
    try:
        response = comprehend.detect_pii_entities(
            Text=test_text,
            LanguageCode='en'
        )
        
        print("✅ Comprehend API working!")
        print(f"Found {len(response['Entities'])} PII entities:")
        for entity in response['Entities']:
            start, end = entity['BeginOffset'], entity['EndOffset']
            print(f"  - {entity['Type']}: {test_text[start:end]}")
        return True
    except Exception as e:
        print(f"❌ Comprehend test failed: {e}")
        return False

if __name__ == '__main__':
    sys.exit(0 if test_comprehend() else 1)
PYTEST

chmod +x /home/ec2-user/test-comprehend.py

# Create layer validation script
cat > /home/ec2-user/validate-layer.py <<'VALPY'
#!/usr/bin/env python3
"""Validate Lambda layer contents"""
import zipfile
import sys

def validate_layer(layer_path='/home/ec2-user/pdf-layer.zip'):
    required_packages = ['PyPDF2', 'reportlab']
    
    print(f"Validating layer: {layer_path}")
    
    try:
        with zipfile.ZipFile(layer_path, 'r') as zf:
            files = zf.namelist()
            print(f"✅ Layer contains {len(files)} files")
            
            for pkg in required_packages:
                pkg_files = [f for f in files if pkg in f]
                if pkg_files:
                    print(f"✅ {pkg}: {len(pkg_files)} files")
                else:
                    print(f"❌ {pkg}: NOT FOUND")
                    return False
            
            # Check size
            import os
            size_mb = os.path.getsize(layer_path) / (1024 * 1024)
            print(f"Layer size: {size_mb:.2f} MB")
            
            if size_mb > 50:
                print("⚠️  Warning: Layer > 50MB (Lambda limit: 50MB zipped)")
                
            return True
    except Exception as e:
        print(f"❌ Validation failed: {e}")
        return False

if __name__ == '__main__':
    sys.exit(0 if validate_layer() else 1)
VALPY

chmod +x /home/ec2-user/validate-layer.py

# Create sample PII document generator
cat > /home/ec2-user/create-test-files.py <<'TESTPY'
#!/usr/bin/env python3
"""Generate sample PII test files"""

def create_test_files():
    # TXT file with PII
    with open('/home/ec2-user/sample-pii.txt', 'w') as f:
        f.write("""Customer Information:
Name: John Doe
Email: john.doe@example.com
Phone: (555) 123-4567
SSN: 123-45-6789
Credit Card: 4532-1234-5678-9012
Address: 123 Main Street, San Francisco, CA 94102
""")
    print("✅ Created sample-pii.txt")
    
    # JSON file with PII
    import json
    data = {
        "customers": [
            {
                "name": "Jane Smith",
                "email": "jane.smith@example.com",
                "ssn": "987-65-4321",
                "phone": "555-987-6543"
            }
        ]
    }
    with open('/home/ec2-user/sample-pii.json', 'w') as f:
        json.dump(data, f, indent=2)
    print("✅ Created sample-pii.json")
    
    print("\nTest files ready in /home/ec2-user/")

if __name__ == '__main__':
    create_test_files()
TESTPY

chmod +x /home/ec2-user/create-test-files.py

# Auto-build Lambda layer on instance launch
echo "Auto-building Lambda layer..."
sudo -u ec2-user /home/ec2-user/build-lambda-layer.sh

# Run validation
echo "Validating layer..."
sudo -u ec2-user python3 /home/ec2-user/validate-layer.py

# Test Comprehend (requires IAM permissions)
echo "Testing Comprehend API..."
sudo -u ec2-user python3 /home/ec2-user/test-comprehend.py || echo "⚠️  Comprehend test skipped (may need IAM role)"

# Create test files
echo "Creating test files..."
sudo -u ec2-user python3 /home/ec2-user/create-test-files.py

# Start and enable services
systemctl daemon-reload
systemctl enable nginx
systemctl start nginx

echo ""
echo "========================================="
echo "EC2 Setup Complete!"
echo "========================================="
echo "Terraform: $(terraform version | head -n1)"
echo "Lambda layer: /home/ec2-user/pdf-layer.zip"
echo ""
echo "Available scripts:"
echo "  ./build-lambda-layer.sh  - Rebuild layer"
echo "  ./test-comprehend.py     - Test Comprehend API"
echo "  ./validate-layer.py      - Validate layer contents"
echo "  ./create-test-files.py   - Generate PII test files"
echo ""
echo "Test files:"
echo "  sample-pii.txt  - Text with PII"
echo "  sample-pii.json - JSON with PII"
echo "========================================="
