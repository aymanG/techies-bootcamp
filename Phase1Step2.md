# Phase 1 - Step 2: CloudFront CDN Setup

## Goal
Add CloudFront CDN for better performance, HTTPS support, and global distribution

## Prerequisites
- Step 1 completed successfully
- `step1-config.sh` file with your bucket name

## Step 2.1: Load Previous Configuration

```bash
# Load your bucket name from Step 1
source step1-config.sh
echo "Using bucket: $BUCKET_NAME"
```

## Step 2.2: Create CloudFront Distribution

First, create a distribution configuration file `cloudfront-config.json`:

```json
{
  "CallerReference": "devops-bootcamp-dist-1",
  "Comment": "DevOps Bootcamp CloudFront Distribution",
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-BUCKET_NAME",
        "DomainName": "BUCKET_NAME.s3-website-us-east-1.amazonaws.com",
        "CustomOriginConfig": {
          "HTTPPort": 80,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only"
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-BUCKET_NAME",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"]
    },
    "Compress": true,
    "MinTTL": 0,
    "DefaultTTL": 86400,
    "MaxTTL": 31536000,
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      }
    },
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    }
  },
  "Enabled": true,
  "PriceClass": "PriceClass_100",
  "CustomErrorResponses": {
    "Quantity": 1,
    "Items": [
      {
        "ErrorCode": 404,
        "ResponsePagePath": "/error.html",
        "ResponseCode": "404",
        "ErrorCachingMinTTL": 300
      }
    ]
  }
}
```

Now create the distribution:

```bash
# Replace BUCKET_NAME in the config file
sed -i "s/BUCKET_NAME/$BUCKET_NAME/g" cloudfront-config.json

# Create CloudFront distribution
DISTRIBUTION_OUTPUT=$(aws cloudfront create-distribution \
  --distribution-config file://cloudfront-config.json \
  --output json)

# Extract Distribution ID and Domain Name
DISTRIBUTION_ID=$(echo $DISTRIBUTION_OUTPUT | jq -r '.Distribution.Id')
CLOUDFRONT_DOMAIN=$(echo $DISTRIBUTION_OUTPUT | jq -r '.Distribution.DomainName')

echo "Distribution ID: $DISTRIBUTION_ID"
echo "CloudFront Domain: $CLOUDFRONT_DOMAIN"
echo "CloudFront URL: https://$CLOUDFRONT_DOMAIN"

# Save to config
echo "export DISTRIBUTION_ID=$DISTRIBUTION_ID" >> step1-config.sh
echo "export CLOUDFRONT_DOMAIN=$CLOUDFRONT_DOMAIN" >> step1-config.sh
```

## Step 2.3: Update Website with CloudFront Test

Create an updated `index.html` that shows CloudFront is working:

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
            min-height: 100vh;
        }
        .container {
            text-align: center;
            padding: 20px;
            max-width: 800px;
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
            text-align: left;
        }
        .success {
            color: #00ff88;
        }
        .pending {
            color: #ff9800;
        }
        .info-item {
            margin: 5px 0;
            padding: 5px;
            background: #0a0a0a;
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1 class="pulse">DevOps Bootcamp</h1>
        <p>Learn DevOps by Doing</p>
        
        <div class="status">
            <h2>🚀 Phase 1 - Step 2: CloudFront Active!</h2>
            <p class="success">✓ S3 Static Website Working</p>
            <p class="success" id="cloudfront-status">⏳ CloudFront Status: Checking...</p>
            
            <div class="test-info">
                <div class="info-item">
                    <strong>Access Method:</strong> <span id="access-method">Detecting...</span>
                </div>
                <div class="info-item">
                    <strong>Protocol:</strong> <span id="protocol"></span>
                </div>
                <div class="info-item">
                    <strong>CloudFront Cache:</strong> <span id="cache-status">Checking...</span>
                </div>
                <div class="info-item">
                    <strong>Your IP:</strong> <span id="ip">Loading...</span>
                </div>
                <div class="info-item">
                    <strong>Timestamp:</strong> <span id="timestamp"></span>
                </div>
            </div>
        </div>

        <div style="margin-top: 30px; padding: 20px; background: #1a1a1a; border-radius: 10px;">
            <h3>Next Steps Preview:</h3>
            <p style="color: #888;">Step 3: Add Cognito Authentication</p>
            <p style="color: #888;">Step 4: Create Lambda Functions</p>
            <p style="color: #888;">Step 5: Build API Gateway</p>
        </div>
    </div>

    <script>
        // Show current timestamp
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
        
        // Detect protocol
        document.getElementById('protocol').textContent = window.location.protocol;
        
        // Detect if accessed via CloudFront
        const host = window.location.hostname;
        let accessMethod = 'Unknown';
        let cloudfrontStatus = '❌ Not using CloudFront';
        
        if (host.includes('cloudfront.net')) {
            accessMethod = 'CloudFront CDN';
            cloudfrontStatus = '✅ CloudFront is working!';
            document.getElementById('cloudfront-status').className = 'success';
        } else if (host.includes('s3-website')) {
            accessMethod = 'S3 Direct';
            cloudfrontStatus = '⚠️ Using S3 directly (CloudFront not active yet)';
            document.getElementById('cloudfront-status').className = 'pending';
        }
        
        document.getElementById('access-method').textContent = accessMethod;
        document.getElementById('cloudfront-status').textContent = cloudfrontStatus;
        
        // Check cache headers (only works if served via CloudFront)
        fetch(window.location.href, { method: 'HEAD' })
            .then(response => {
                const cacheStatus = response.headers.get('x-cache') || 'Not available';
                document.getElementById('cache-status').textContent = cacheStatus;
            })
            .catch(() => {
                document.getElementById('cache-status').textContent = 'Unable to check';
            });
        
        // Get user's IP
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

Upload the updated file:

```bash
# Upload updated index.html
aws s3 cp index.html s3://$BUCKET_NAME/

# Create a CloudFront invalidation to clear cache
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*"
```

## Step 2.4: Wait for Distribution Deployment

CloudFront takes 10-15 minutes to deploy globally. Check status:

```bash
# Check distribution status
aws cloudfront get-distribution --id $DISTRIBUTION_ID \
  --query 'Distribution.Status' --output text

# Wait for deployment (this will check every 30 seconds)
echo "Waiting for CloudFront deployment (this takes 10-15 minutes)..."
while [ "$(aws cloudfront get-distribution --id $DISTRIBUTION_ID --query 'Distribution.Status' --output text)" != "Deployed" ]; do
    echo -n "."
    sleep 30
done
echo "CloudFront is deployed!"
```

## Step 2.5: Test CloudFront Access

```bash
# Test CloudFront URL
echo "Testing CloudFront URL: https://$CLOUDFRONT_DOMAIN"
curl -I https://$CLOUDFRONT_DOMAIN

# Compare load times
echo -e "\n📊 Performance Comparison:"
echo "S3 Direct:"
time curl -s $WEBSITE_URL > /dev/null

echo -e "\nCloudFront:"
time curl -s https://$CLOUDFRONT_DOMAIN > /dev/null
```

## Validation Checklist

```bash
# 1. Check distribution exists
aws cloudfront list-distributions --query "DistributionList.Items[?Id=='$DISTRIBUTION_ID'].Status" --output text
echo "✓ CloudFront distribution exists"

# 2. Test HTTPS access
curl -s https://$CLOUDFRONT_DOMAIN | grep "CloudFront Active" && echo "✓ HTTPS access working"

# 3. Check cache headers
curl -sI https://$CLOUDFRONT_DOMAIN | grep -i "x-cache" && echo "✓ CloudFront caching active"

# 4. Verify S3 origin
aws cloudfront get-distribution --id $DISTRIBUTION_ID \
  --query 'Distribution.DistributionConfig.Origins.Items[0].DomainName' --output text
echo "✓ S3 origin configured"

# 5. Save final configuration
cat > step2-config.sh << EOF
$(cat step1-config.sh)
export CLOUDFRONT_URL=https://$CLOUDFRONT_DOMAIN
EOF
echo "✓ Configuration saved to step2-config.sh"
```

## Cost Analysis
- CloudFront: First 1TB/month free tier
- After free tier: ~$0.085 per GB
- **Total for Step 2: $0 (within free tier)**

## Benefits of CloudFront
1. ✅ **HTTPS by default** - Security best practice
2. ✅ **Global edge locations** - Fast loading worldwide
3. ✅ **DDoS protection** - Built-in AWS Shield
4. ✅ **Compression** - Smaller file sizes
5. ✅ **Caching** - Reduced S3 requests

## Troubleshooting

1. **If distribution is stuck in "InProgress"**:
   - This is normal, wait up to 20 minutes
   - Check: `aws cloudfront get-distribution --id $DISTRIBUTION_ID --query 'Distribution.Status'`

2. **If you get access denied**:
   - Ensure S3 bucket policy allows CloudFront
   - Check origin settings in CloudFront

3. **If page shows old content**:
   - Create an invalidation: `aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/*"`

## What You've Achieved
- ✅ Website served over HTTPS
- ✅ Global CDN distribution
- ✅ Automatic HTTP to HTTPS redirect
- ✅ Error page handling
- ✅ Performance optimization

## Next Step Preview
In Step 3, we'll:
1. Set up Cognito User Pool
2. Add user registration
3. Add email verification
4. Create login functionality

---

**Once CloudFront shows "Deployed" and you can access your site via HTTPS, Step 2 is complete!** The page should show "CloudFront is working!" in green.
