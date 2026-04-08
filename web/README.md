# PII Redaction Web Interface

Simple, clean web UI for the PII redaction service.

## Features

- 📤 Drag-and-drop file upload
- 🎨 Clean, modern design
- 📱 Mobile responsive
- ⚙️ Configurable redaction modes
- 📥 Direct download of redacted files
- 🔒 Supports PDF, TXT, JSON, CSV

## Setup

### 1. Deploy Infrastructure

```bash
# Deploy everything including website
./terraform_startup.sh
```

### 2. Get Website URL

```bash
terraform output website_url
```

### 3. Configure JavaScript

Update `web/app.js` with your bucket name:

```javascript
const CONFIG = {
    API_URL: 'https://pii-api.sebekgo.com',
    BUCKET_NAME: 'your-actual-bucket-name',  // Get from: terraform output pii_data_bucket_name
    REGION: 'us-west-2'
};
```

Or pass as URL parameter:
```
http://your-website-url/?bucket=your-bucket-name
```

### 4. Update Website Files

After editing, upload changes:

```bash
aws s3 cp web/app.js s3://$(terraform output -raw website_bucket_name)/app.js
```

## Authentication Note

The current demo uses placeholder authentication. For production:

### Option 1: AWS Cognito (Recommended)
```javascript
// Add AWS Amplify
import { Amplify, Auth } from 'aws-amplify';

// Configure Cognito
Amplify.configure({
    Auth: {
        region: 'us-west-2',
        userPoolId: 'your-pool-id',
        userPoolWebClientId: 'your-client-id'
    }
});

// Get credentials
const credentials = await Auth.currentCredentials();
```

### Option 2: Pre-signed URLs
- Create backend API endpoint
- Generate pre-signed S3 upload URLs
- Generate pre-signed API Gateway invocation URLs

### Option 3: API Key
- Add API key to API Gateway
- Include key in requests
- Less secure but simpler

## Customization Ideas

### Colors
Edit `styles.css`:
```css
:root {
    --primary-color: #your-color;
}
```

### Branding
- Replace header text in `index.html`
- Add logo image
- Update footer

### Features to Add
- [ ] Preview original file
- [ ] Side-by-side comparison
- [ ] Batch processing
- [ ] Download as ZIP
- [ ] Email delivery
- [ ] Save to cloud storage
- [ ] Audit logs
- [ ] Cost estimation
- [ ] Processing history

## File Structure

```
web/
├── index.html    # Main page structure
├── styles.css    # Styling and layout
└── app.js        # Application logic
```

## Browser Support

- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)
- Mobile browsers

## Development

Test locally:
```bash
cd web
python -m http.server 8000
# Open http://localhost:8000
```

## Deployment

Automatic with Terraform:
```bash
terraform apply
```

Manual update:
```bash
aws s3 sync web/ s3://$(terraform output -raw website_bucket_name)/ --exclude "*.md"
```

## Next Steps

1. **Add Authentication** - Implement Cognito or API keys
2. **Add CloudFront** - For HTTPS and global CDN
3. **Custom Domain** - Map to your domain (e.g., redact.sebekgo.com)
4. **Analytics** - Add Google Analytics or CloudWatch RUM
5. **Error Handling** - Better error messages
6. **Loading States** - Skeleton screens
7. **Dark Mode** - Toggle theme

## Cost

Hosting cost is minimal:
- S3 hosting: ~$0.50/month
- Data transfer: First 100GB free
- Requests: $0.005 per 1,000 requests

For 1,000 users/month: < $2/month
