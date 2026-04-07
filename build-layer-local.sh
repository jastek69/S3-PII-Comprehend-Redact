#!/usr/bin/env bash
# Build Lambda layer locally for PDF processing

echo "Building Lambda layer locally..."

# Create temp directory
mkdir -p lambda/python

# Install packages
pip install -t lambda/python PyPDF2==3.0.1 reportlab==4.0.7

# Create zip
cd lambda
zip -r pdf-layer.zip python/
cd ..

# Cleanup
rm -rf lambda/python

echo "✓ Lambda layer created: lambda/pdf-layer.zip"
ls -lh lambda/pdf-layer.zip
