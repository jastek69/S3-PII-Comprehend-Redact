#!/bin/bash
# Build Lambda Layer for PDF processing dependencies
# This creates a Lambda layer with PyPDF2 and reportlab

set -e

echo "Building Lambda Layer for PDF processing..."

# Create temporary directory
LAYER_DIR="lambda-layer"
rm -rf $LAYER_DIR
mkdir -p $LAYER_DIR/python

# Install dependencies
echo "Installing Python dependencies..."
pip install -r requirements.txt -t $LAYER_DIR/python/

# Create zip file
echo "Creating layer zip file..."
cd $LAYER_DIR
zip -r ../pdf-layer.zip python/
cd ..

# Cleanup
rm -rf $LAYER_DIR

echo "✅ Lambda layer created: pdf-layer.zip"
echo "File size: $(du -h pdf-layer.zip | cut -f1)"
echo ""
echo "Now run: terraform apply"
