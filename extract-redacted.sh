#!/usr/bin/env bash
# Extract redacted PDF from Lambda response

if [ ! -f response.json ]; then
    echo "Error: response.json not found"
    echo "Run the Lambda invoke command first"
    exit 1
fi

# Check if it's a PDF (base64 encoded)
if grep -q '"isBase64Encoded":true' response.json; then
    echo "Extracting PDF..."
    cat response.json | jq -r '.body' | base64 -d > redacted.pdf
    echo "✓ Saved to: redacted.pdf"
    ls -lh redacted.pdf
else
    echo "Extracting text..."
    cat response.json | jq -r '.body' > redacted.txt
    echo "✓ Saved to: redacted.txt"
fi
