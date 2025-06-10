# Phase 1 - Step 1: S3 Static Website Setup

## Goal
Create a simple static website on S3 that displays "DevOps Bootcamp - Coming Soon"

## Prerequisites
- AWS CLI installed and configured
- AWS account with appropriate permissions

## Step 1.1: Create S3 Bucket

```bash
# Set your unique bucket name (must be globally unique)
export BUCKET_NAME="devops-bootcamp-$(date +%s)"
echo "Bucket name: $BUCKET_NAME"

# Create the bucket
aws s3 mb s3://$BUCKET_NAME --region us-east-1

# Enable static website hosting
aws s3 website s3://$BUCKET_NAME \
  --index-document index.html \
  --error-document error.html
```

## Step 1.2: Create Bucket Policy for Public Access

Create a file called `bucket-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::BUCKET_NAME/*"
    }
  ]
}
```

Apply the policy:

```bash
# Replace BUCKET_NAME in the policy file
sed -i "s/BUCKET_NAME/$BUCKET_NAME/g" bucket-policy.json

# Apply the bucket policy
aws s3api put-bucket-policy \
  --bucket $BUCKET_NAME \
  --policy file://bucket-policy.json

# Disable "Block Public Access" settings
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
  "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"
```

## Step 1.3: Create Simple Test Website

Create `index.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DevOps Bootcamp</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background-color: #0a0a0a;
            color: #00ff88;
            font-family: 'Courier New', monospace;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
        }
        .container {
            text-align: center;
            padding: 20px;
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 1rem;
            text-shadow: 0 0 20px rgba(0, 255, 136, 0.5);
        }
        .status {
            background: #1a1a1a;
            padding: 20px;
            border-radius: 10px;
            margin-top: 30px;
            border: 2px solid #333;
        }
        .pulse {
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
        .test-info {
            margin-top: 20px;
            font-size: 0.9rem;
            color: #888;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1 class="pulse">DevOps Bootcamp</h1>
        <p>Learn DevOps by Doing</p>
        
        <div class="status">
            <h2>🚀 Phase 1 - Step 1: Complete!</h2>
            <p>Static website is working on S3</p>
            <div class="test-info">
                <p>Timestamp: <span id="timestamp"></span></p>
                <p>Your IP: <span id="ip">Loading...</span></p>
            </div>
        </div>
    </div>

    <script>
        // Show current timestamp
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
        
        // Get user's IP (for testing)
        fetch('https://api.ipify.org?format=json')
            .then(response => response.json())
            .then(data => {
                document.getElementById('ip').textContent = data.ip;
            })
            .catch(() => {
                document.getElementById('ip').textContent = 'Unable to fetch';
            });
    </script>
</body>
</html>
```

Create `error.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>404 - DevOps Bootcamp</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background-color: #0a0a0a;
            color: #ff0088;
            font-family: 'Courier New', monospace;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
        }
        .container {
            text-align: center;
        }
        h1 {
            font-size: 5rem;
            margin: 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>404</h1>
        <p>Command not found</p>
        <p><a href="/" style="color: #00ff88;">Return to home</a></p>
    </div>
</body>
</html>
```

## Step 1.4: Upload Files to S3

```bash
# Upload the files
aws s3 cp index.html s3://$BUCKET_NAME/
aws s3 cp error.html s3://$BUCKET_NAME/

# Verify files are uploaded
aws s3 ls s3://$BUCKET_NAME/
```

## Step 1.5: Test Your Website

```bash
# Get your website URL
export WEBSITE_URL="http://$BUCKET_NAME.s3-website-us-east-1.amazonaws.com"
echo "Your website URL: $WEBSITE_URL"

# Test with curl
curl -I $WEBSITE_URL

# Open in browser (Linux)
xdg-open $WEBSITE_URL 2>/dev/null || open $WEBSITE_URL 2>/dev/null || echo "Open in browser: $WEBSITE_URL"
```

## Validation Checklist

Run these tests to confirm Step 1 is working:

```bash
# 1. Check bucket exists
aws s3 ls | grep $BUCKET_NAME
echo "✓ Bucket exists"

# 2. Check website configuration
aws s3api get-bucket-website --bucket $BUCKET_NAME
echo "✓ Website hosting enabled"

# 3. Check public access
curl -s $WEBSITE_URL | grep "DevOps Bootcamp" && echo "✓ Website is publicly accessible"

# 4. Check 404 page
curl -s $WEBSITE_URL/nonexistent | grep "404" && echo "✓ Error page working"

# 5. Save configuration for next steps
cat > step1-config.sh << EOF
export BUCKET_NAME=$BUCKET_NAME
export WEBSITE_URL=$WEBSITE_URL
export REGION=us-east-1
EOF
echo "✓ Configuration saved to step1-config.sh"
```

## Cost Analysis
- S3 Storage: ~$0.023 per GB per month (essentially free for a few HTML files)
- S3 Requests: ~$0.0004 per 1,000 requests
- **Total for Step 1: Less than $0.01/month**

## Troubleshooting

If the website isn't accessible:

1. **Check bucket policy**:
   ```bash
   aws s3api get-bucket-policy --bucket $BUCKET_NAME
   ```

2. **Check public access block**:
   ```bash
   aws s3api get-public-access-block --bucket $BUCKET_NAME
   ```

3. **Check DNS propagation** (may take 1-2 minutes):
   ```bash
   nslookup $BUCKET_NAME.s3-website-us-east-1.amazonaws.com
   ```

## Next Step Preview
Once this is working, we'll:
1. Add CloudFront CDN for better performance
2. Set up a custom domain (optional)
3. Add HTTPS support

## Clean Up (Only if needed)
```bash
# To remove everything and start over
aws s3 rm s3://$BUCKET_NAME --recursive
aws s3 rb s3://$BUCKET_NAME
```

---

**Ready to proceed?** Once you see "DevOps Bootcamp" in your browser with the green text on black background, Step 1 is complete! Save the `step1-config.sh` file as we'll need those values for the next steps.
