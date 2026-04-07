"""
Create a sample PDF file with PII data for testing
"""

try:
    from reportlab.pdfgen import canvas
    from reportlab.lib.pagesizes import letter
    from reportlab.lib.units import inch
except ImportError:
    print("Error: reportlab is required. Install it with: pip install reportlab")
    exit(1)

def create_sample_pii_pdf(filename="sample-pii.pdf"):
    """Create a PDF with sample PII data"""
    
    # Create PDF
    pdf = canvas.Canvas(filename, pagesize=letter)
    width, height = letter
    
    # Set up text
    pdf.setFont("Helvetica-Bold", 16)
    pdf.drawString(inch, height - inch, "Customer Support Ticket #12345")
    
    pdf.setFont("Helvetica", 12)
    y = height - 1.5 * inch
    
    lines = [
        "",
        "Customer Information:",
        "Name: John Smith",
        "Email: john.smith@example.com",
        "Phone: 555-123-4567",
        "SSN: 123-45-6789",
        "Address: 123 Main Street, New York, NY 10001",
        "",
        "Payment Information:",
        "Credit Card: 4532-1234-5678-9010",
        "CVV: 123",
        "Expiry: 12/2025",
        "",
        "Issue Description:",
        "Customer reported unauthorized charges on their account.",
        "Multiple transactions were flagged by the fraud detection system.",
        "Customer's driver license #: D1234567",
        "IP Address used for login: 192.168.1.100",
        "",
        "Account Details:",
        "Bank Account Number: 987654321",
        "Bank Routing Number: 123456789",
        "Username: johnsmith2024",
        "",
        "Additional Notes:",
        "This is a test document containing various types of PII data",
        "for testing the PII redaction system with PDF files.",
        "All information is fictional and for testing purposes only.",
    ]
    
    for line in lines:
        pdf.drawString(inch, y, line)
        y -= 0.25 * inch
    
    pdf.save()
    print(f"✅ Created {filename}")
    print(f"File contains multiple PII types: NAME, EMAIL, PHONE, SSN, ADDRESS,")
    print(f"CREDIT_DEBIT_NUMBER, DRIVER_ID, IP_ADDRESS, BANK_ACCOUNT_NUMBER, etc.")

if __name__ == "__main__":
    create_sample_pii_pdf()
