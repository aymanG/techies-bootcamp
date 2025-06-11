# Phase 1 - Step 4: Lambda Functions Backend

## Goal
Create serverless backend functions to handle user data and business logic

## Prerequisites
- Step 3 completed (Cognito authentication working)
- `step3-config.sh` file with your configuration

## Step 4.1: Load Configuration and Setup

```bash
# Load your previous configuration
source step3-config.sh
echo "Using User Pool: $USER_POOL_ID"

# Set up Lambda environment
export LAMBDA_ROLE_NAME="devops-bootcamp-lambda-role"
export LAMBDA_FUNCTION_NAME="devops-bootcamp-api"
```

## Step 4.2: Create IAM Role for Lambda

First, create the trust policy file `lambda-trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Now create the role and attach policies:

```bash
# Create IAM role for Lambda
ROLE_OUTPUT=$(aws iam create-role \
  --role-name $LAMBDA_ROLE_NAME \
  --assume-role-policy-document file://lambda-trust-policy.json \
  --output json)

LAMBDA_ROLE_ARN=$(echo $ROLE_OUTPUT | jq -r '.Role.Arn')
echo "Lambda Role ARN: $LAMBDA_ROLE_ARN"

# Attach basic Lambda execution policy
aws iam attach-role-policy \
  --role-name $LAMBDA_ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create and attach custom policy for Cognito and DynamoDB
cat > lambda-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cognito-idp:AdminGetUser",
        "cognito-idp:ListUsers",
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create custom policy
POLICY_OUTPUT=$(aws iam create-policy \
  --policy-name devops-bootcamp-lambda-policy \
  --policy-document file://lambda-policy.json \
  --output json)

POLICY_ARN=$(echo $POLICY_OUTPUT | jq -r '.Policy.Arn')

# Attach custom policy to role
aws iam attach-role-policy \
  --role-name $LAMBDA_ROLE_NAME \
  --policy-arn $POLICY_ARN

# Save to config
echo "export LAMBDA_ROLE_ARN=$LAMBDA_ROLE_ARN" >> step3-config.sh

# Wait for role to propagate
echo "Waiting 10 seconds for IAM role to propagate..."
sleep 10
```

## Step 4.3: Create Lambda Function Code

Create a directory for your Lambda function:

```bash
mkdir -p lambda-function
cd lambda-function
```

Create `index.js`:

```javascript
// Lambda function handler
const AWS = require('aws-sdk');
const cognito = new AWS.CognitoIdentityServiceProvider();
const dynamodb = new AWS.DynamoDB.DocumentClient();

// Table name (we'll create this in Step 6)
const USERS_TABLE = process.env.USERS_TABLE || 'devops-bootcamp-users';

// CORS headers for browser access
const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
};

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    // Handle preflight requests
    if (event.httpMethod === 'OPTIONS') {
        return {
            statusCode: 200,
            headers: corsHeaders,
            body: ''
        };
    }
    
    try {
        // Parse the path and method
        const path = event.path || event.rawPath || '/';
        const method = event.httpMethod || event.requestContext?.http?.method || 'GET';
        
        // Get the authorization token
        const token = event.headers?.Authorization || event.headers?.authorization || '';
        
        // Route the request
        let response;
        
        if (path === '/api/health') {
            response = await handleHealth();
        } else if (path === '/api/user/profile' && method === 'GET') {
            response = await handleGetProfile(token);
        } else if (path === '/api/user/progress' && method === 'GET') {
            response = await handleGetProgress(token);
        } else if (path === '/api/user/progress' && method === 'POST') {
            response = await handleUpdateProgress(token, JSON.parse(event.body || '{}'));
        } else if (path === '/api/challenges' && method === 'GET') {
            response = await handleGetChallenges();
        } else {
            response = {
                statusCode: 404,
                body: JSON.stringify({ error: 'Not found' })
            };
        }
        
        // Add CORS headers to response
        response.headers = { ...corsHeaders, ...response.headers };
        return response;
        
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            headers: corsHeaders,
            body: JSON.stringify({ error: error.message || 'Internal server error' })
        };
    }
};

// Health check endpoint
async function handleHealth() {
    return {
        statusCode: 200,
        body: JSON.stringify({
            status: 'healthy',
            timestamp: new Date().toISOString(),
            service: 'devops-bootcamp-api'
        })
    };
}

// Get user profile from token
async function handleGetProfile(token) {
    if (!token) {
        return {
            statusCode: 401,
            body: JSON.stringify({ error: 'No authorization token' })
        };
    }
    
    try {
        // Decode the JWT token to get user info
        // In production, you should verify the token properly
        const tokenParts = token.split('.');
        if (tokenParts.length !== 3) {
            throw new Error('Invalid token format');
        }
        
        const payload = JSON.parse(Buffer.from(tokenParts[1], 'base64').toString());
        const email = payload.email || payload['cognito:username'];
        const sub = payload.sub;
        
        // Get or create user record in DynamoDB
        try {
            const result = await dynamodb.get({
                TableName: USERS_TABLE,
                Key: { userId: sub }
            }).promise();
            
            if (result.Item) {
                return {
                    statusCode: 200,
                    body: JSON.stringify(result.Item)
                };
            }
        } catch (dbError) {
            console.log('DynamoDB not set up yet, returning basic profile');
        }
        
        // Return basic profile if no DynamoDB record
        const profile = {
            userId: sub,
            email: email,
            points: 0,
            rank: 'Novice',
            completedChallenges: [],
            createdAt: new Date().toISOString()
        };
        
        return {
            statusCode: 200,
            body: JSON.stringify(profile)
        };
        
    } catch (error) {
        console.error('Profile error:', error);
        return {
            statusCode: 401,
            body: JSON.stringify({ error: 'Invalid token' })
        };
    }
}

// Get user progress
async function handleGetProgress(token) {
    if (!token) {
        return {
            statusCode: 401,
            body: JSON.stringify({ error: 'No authorization token' })
        };
    }
    
    // For now, return mock progress
    const progress = {
        totalPoints: 0,
        completedChallenges: [],
        currentStreak: 0,
        lastActivity: new Date().toISOString()
    };
    
    return {
        statusCode: 200,
        body: JSON.stringify(progress)
    };
}

// Update user progress
async function handleUpdateProgress(token, data) {
    if (!token) {
        return {
            statusCode: 401,
            body: JSON.stringify({ error: 'No authorization token' })
        };
    }
    
    console.log('Update progress:', data);
    
    return {
        statusCode: 200,
        body: JSON.stringify({
            success: true,
            message: 'Progress updated',
            points: data.points || 0
        })
    };
}

// Get available challenges
async function handleGetChallenges() {
    // Static challenge data for now
    const challenges = [
        {
            id: 'welcome',
            name: 'Welcome to DevOps Academy',
            description: 'Get familiar with the platform and access your first container',
            level: 0,
            difficulty: 'beginner',
            points: 10,
            category: 'basics',
            prerequisites: []
        },
        {
            id: 'terminal-basics',
            name: 'Terminal Navigation',
            description: 'Master basic terminal commands: ls, cd, pwd, cat',
            level: 1,
            difficulty: 'beginner',
            points: 20,
            category: 'linux',
            prerequisites: ['welcome']
        },
        {
            id: 'file-permissions',
            name: 'File Permissions',
            description: 'Understand and modify file permissions using chmod',
            level: 2,
            difficulty: 'intermediate',
            points: 30,
            category: 'linux',
            prerequisites: ['terminal-basics']
        },
        {
            id: 'shell-scripting',
            name: 'Shell Scripting Basics',
            description: 'Write your first bash scripts',
            level: 3,
            difficulty: 'intermediate',
            points: 40,
            category: 'linux',
            prerequisites: ['file-permissions']
        },
        {
            id: 'docker-intro',
            name: 'Introduction to Docker',
            description: 'Learn containerization basics',
            level: 4,
            difficulty: 'advanced',
            points: 50,
            category: 'docker',
            prerequisites: ['shell-scripting']
        }
    ];
    
    return {
        statusCode: 200,
        body: JSON.stringify({
            challenges: challenges,
            total: challenges.length
        })
    };
}
```

Create `package.json`:

```json
{
  "name": "devops-bootcamp-lambda",
  "version": "1.0.0",
  "description": "Lambda function for DevOps Bootcamp API",
  "main": "index.js",
  "dependencies": {
    "aws-sdk": "^2.1472.0"
  }
}
```

## Step 4.4: Deploy Lambda Function

```bash
# Install dependencies (AWS SDK is included in Lambda, but good for local testing)
npm install

# Create deployment package
zip -r function.zip .

# Create Lambda function
LAMBDA_OUTPUT=$(aws lambda create-function \
  --function-name $LAMBDA_FUNCTION_NAME \
  --runtime nodejs18.x \
  --role $LAMBDA_ROLE_ARN \
  --handler index.handler \
  --zip-file fileb://function.zip \
  --timeout 30 \
  --memory-size 256 \
  --environment Variables="{USERS_TABLE=devops-bootcamp-users,USER_POOL_ID=$USER_POOL_ID}" \
  --output json)

LAMBDA_ARN=$(echo $LAMBDA_OUTPUT | jq -r '.FunctionArn')
echo "Lambda Function ARN: $LAMBDA_ARN"

# Save to config
echo "export LAMBDA_ARN=$LAMBDA_ARN" >> ../step3-config.sh
echo "export LAMBDA_FUNCTION_NAME=$LAMBDA_FUNCTION_NAME" >> ../step3-config.sh

# Go back to main directory
cd ..
```

## Step 4.5: Test Lambda Function

Test the health endpoint:

```bash
# Create test event
cat > test-event.json << EOF
{
  "path": "/api/health",
  "httpMethod": "GET",
  "headers": {}
}
EOF

# Invoke Lambda function
aws lambda invoke \
  --function-name $LAMBDA_FUNCTION_NAME \
  --payload file://test-event.json \
  --cli-binary-format raw-in-base64-out \
  response.json

# Check response
cat response.json | jq .
```

Test with authentication:

```bash
# First, get a token by logging into your web app
# Then create a test with authorization

cat > test-auth-event.json << EOF
{
  "path": "/api/user/profile",
  "httpMethod": "GET",
  "headers": {
    "Authorization": "YOUR_JWT_TOKEN_HERE"
  }
}
EOF

# Test authenticated endpoint
aws lambda invoke \
  --function-name $LAMBDA_FUNCTION_NAME \
  --payload file://test-auth-event.json \
  --cli-binary-format raw-in-base64-out \
  auth-response.json

cat auth-response.json | jq .
```

## Step 4.6: Create Lambda Function URL (Quick Testing)

For quick testing before we set up API Gateway:

```bash
# Create function URL for testing
URL_OUTPUT=$(aws lambda create-function-url-config \
  --function-name $LAMBDA_FUNCTION_NAME \
  --auth-type NONE \
  --cors '{
    "AllowOrigins": ["*"],
    "AllowMethods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    "AllowHeaders": ["Content-Type", "Authorization"],
    "MaxAge": 86400
  }' \
  --output json)

LAMBDA_URL=$(echo $URL_OUTPUT | jq -r '.FunctionUrl')
echo "Lambda Function URL: $LAMBDA_URL"

# Save to config
echo "export LAMBDA_URL=$LAMBDA_URL" >> step3-config.sh

# Test the URL
curl "${LAMBDA_URL}api/health" | jq .
```

## Step 4.7: Update Frontend to Test Backend

Create `api-test.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DevOps Bootcamp - API Test</title>
    <style>
        body {
            margin: 0;
            padding: 20px;
            background-color: #0a0a0a;
            color: #00ff88;
            font-family: 'Courier New', monospace;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
        }
        h1 {
            text-shadow: 0 0 20px rgba(0, 255, 136, 0.5);
        }
        .test-section {
            background: #1a1a1a;
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
            border: 2px solid #333;
        }
        button {
            background: #00ff88;
            color: #0a0a0a;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            font-weight: bold;
            margin: 5px;
        }
        button:hover {
            background: #00cc6f;
        }
        .response {
            background: #0a0a0a;
            padding: 15px;
            border-radius: 5px;
            margin-top: 15px;
            white-space: pre-wrap;
            font-size: 0.9rem;
            border: 1px solid #333;
        }
        .success { border-color: #00ff88; }
        .error { border-color: #ff0088; }
        .loading { opacity: 0.5; }
    </style>
</head>
<body>
    <div class="container">
        <h1>API Backend Test</h1>
        
        <div class="test-section">
            <h2>1. Health Check (No Auth Required)</h2>
            <button onclick="testHealth()">Test Health Endpoint</button>
            <div id="health-response" class="response"></div>
        </div>
        
        <div class="test-section">
            <h2>2. Get Challenges (No Auth Required)</h2>
            <button onclick="testChallenges()">Get Challenges</button>
            <div id="challenges-response" class="response"></div>
        </div>
        
        <div class="test-section">
            <h2>3. Get Profile (Auth Required)</h2>
            <p>First login on the auth page, then test here</p>
            <button onclick="testProfile()">Get My Profile</button>
            <div id="profile-response" class="response"></div>
        </div>
        
        <div class="test-section">
            <h2>4. Update Progress (Auth Required)</h2>
            <button onclick="testProgress()">Update Progress</button>
            <div id="progress-response" class="response"></div>
        </div>
        
        <div class="test-section">
            <h2>Configuration</h2>
            <p>Lambda URL: <span id="lambda-url"></span></p>
            <p>Auth Token: <span id="auth-token">Not logged in</span></p>
        </div>
    </div>

    <script>
        // WILL BE REPLACED BY SED
        const LAMBDA_URL = 'YOUR_LAMBDA_URL';
        
        // Show Lambda URL
        document.getElementById('lambda-url').textContent = LAMBDA_URL;
        
        // Get auth token from Cognito
        function getAuthToken() {
            const token = localStorage.getItem('CognitoIdentityServiceProvider.YOUR_CLIENT_ID.LastAuthUser');
            if (token) {
                const idToken = localStorage.getItem(`CognitoIdentityServiceProvider.YOUR_CLIENT_ID.${token}.idToken`);
                if (idToken) {
                    document.getElementById('auth-token').textContent = 'Found (JWT)';
                    return idToken;
                }
            }
            document.getElementById('auth-token').textContent = 'Not found - please login first';
            return null;
        }
        
        async function makeRequest(path, options = {}) {
            const url = LAMBDA_URL + path;
            const token = getAuthToken();
            
            const headers = {
                'Content-Type': 'application/json',
                ...options.headers
            };
            
            if (token && path.includes('user')) {
                headers['Authorization'] = token;
            }
            
            try {
                const response = await fetch(url, {
                    ...options,
                    headers,
                    mode: 'cors'
                });
                
                const data = await response.json();
                return {
                    status: response.status,
                    data: data,
                    success: response.ok
                };
            } catch (error) {
                return {
                    status: 0,
                    data: { error: error.message },
                    success: false
                };
            }
        }
        
        async function testHealth() {
            const responseEl = document.getElementById('health-response');
            responseEl.textContent = 'Loading...';
            responseEl.className = 'response loading';
            
            const result = await makeRequest('api/health');
            
            responseEl.textContent = JSON.stringify(result, null, 2);
            responseEl.className = `response ${result.success ? 'success' : 'error'}`;
        }
        
        async function testChallenges() {
            const responseEl = document.getElementById('challenges-response');
            responseEl.textContent = 'Loading...';
            responseEl.className = 'response loading';
            
            const result = await makeRequest('api/challenges');
            
            responseEl.textContent = JSON.stringify(result, null, 2);
            responseEl.className = `response ${result.success ? 'success' : 'error'}`;
        }
        
        async function testProfile() {
            const responseEl = document.getElementById('profile-response');
            responseEl.textContent = 'Loading...';
            responseEl.className = 'response loading';
            
            const result = await makeRequest('api/user/profile');
            
            responseEl.textContent = JSON.stringify(result, null, 2);
            responseEl.className = `response ${result.success ? 'success' : 'error'}`;
        }
        
        async function testProgress() {
            const responseEl = document.getElementById('progress-response');
            responseEl.textContent = 'Loading...';
            responseEl.className = 'response loading';
            
            const result = await makeRequest('api/user/progress', {
                method: 'POST',
                body: JSON.stringify({
                    challengeId: 'welcome',
                    completed: true,
                    points: 10
                })
            });
            
            responseEl.textContent = JSON.stringify(result, null, 2);
            responseEl.className = `response ${result.success ? 'success' : 'error'}`;
        }
        
        // Check auth status on load
        window.onload = () => {
            getAuthToken();
        };
    </script>
</body>
</html>
```

Update and upload the test page:

```bash
# Update with your values
sed -i "s|YOUR_LAMBDA_URL|$LAMBDA_URL|g" api-test.html
sed -i "s|YOUR_CLIENT_ID|$PUBLIC_CLIENT_ID|g" api-test.html

# Upload to S3
aws s3 cp api-test.html s3://$BUCKET_NAME/

# Invalidate cache
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/api-test.html"

echo "API test page available at: $CLOUDFRONT_URL/api-test.html"
```

## Validation Checklist

```bash
# 1. Check Lambda function exists
aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME \
  --query 'Configuration.FunctionName' --output text
echo "✓ Lambda function created"

# 2. Test Lambda directly
aws lambda invoke \
  --function-name $LAMBDA_FUNCTION_NAME \
  --payload '{"path":"/api/health","httpMethod":"GET"}' \
  --cli-binary-format raw-in-base64-out \
  health-check.json
cat health-check.json | jq .
echo "✓ Lambda responds to health check"

# 3. Check Function URL
curl -s "${LAMBDA_URL}api/health" | jq .
echo "✓ Function URL accessible"

# 4. List all endpoints
echo "Available endpoints:"
echo "  - ${LAMBDA_URL}api/health (GET)"
echo "  - ${LAMBDA_URL}api/challenges (GET)"
echo "  - ${LAMBDA_URL}api/user/profile (GET, requires auth)"
echo "  - ${LAMBDA_URL}api/user/progress (GET/POST, requires auth)"

# 5. Save configuration
cat > step4-config.sh << EOF
$(cat step3-config.sh)
export LAMBDA_TEST_URL=$CLOUDFRONT_URL/api-test.html
EOF
echo "✓ Configuration saved to step4-config.sh"
```

## Cost Analysis
- Lambda: First 1M requests/month FREE
- After free tier: $0.20 per 1M requests
- Compute: 400,000 GB-seconds FREE/month
- **Total for Step 4: $0 (within free tier)**

## What You've Achieved
- ✅ Serverless backend API
- ✅ JWT token validation
- ✅ Mock challenge data
- ✅ User profile endpoint
- ✅ CORS enabled for browser access

## Troubleshooting

1. **If Lambda creation fails**: Check IAM role was created properly
2. **If Function URL doesn't work**: Ensure CORS is configured
3. **If auth endpoints fail**: Make sure you're logged in on the auth page first
4. **To update Lambda code**:
   ```bash
   cd lambda-function
   zip -r function.zip .
   aws lambda update-function-code \
     --function-name $LAMBDA_FUNCTION_NAME \
     --zip-file fileb://function.zip
   ```

## Next Step Preview
In Step 5, we'll:
1. Create API Gateway for a professional REST API
2. Add request validation
3. Set up proper routing
4. Add API keys (optional)

---

**Test the API by opening the test page and clicking the buttons!** The health check and challenges endpoints should work immediately. For profile endpoints, login on the auth page first.
