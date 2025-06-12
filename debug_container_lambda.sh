#!/bin/bash
# Debug and fix the container Lambda function

# Load configuration
source step6-config-fixed.sh 2>/dev/null || {
    echo "❌ Please run the previous fix scripts first"
    exit 1
}

echo "🔍 Debugging Container Lambda..."

# Check if the Lambda function exists
echo "📋 Step 1: Checking Lambda function status..."

LAMBDA_EXISTS=$(aws lambda get-function --function-name devops-bootcamp-containers 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "❌ Lambda function doesn't exist - creating it..."
    
    # Create the IAM role first if it doesn't exist
    ROLE_EXISTS=$(aws iam get-role --role-name devops-bootcamp-lambda-role 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Creating IAM role..."
        
        cat > lambda-trust-policy.json << 'EOF'
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
EOF

        aws iam create-role \
          --role-name devops-bootcamp-lambda-role \
          --assume-role-policy-document file://lambda-trust-policy.json
        
        aws iam attach-role-policy \
          --role-name devops-bootcamp-lambda-role \
          --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
          
        sleep 10  # Wait for role to propagate
        
        LAMBDA_ROLE_ARN=$(aws iam get-role --role-name devops-bootcamp-lambda-role --query 'Role.Arn' --output text)
    else
        LAMBDA_ROLE_ARN=$(echo $ROLE_EXISTS | jq -r '.Role.Arn')
    fi
    
    echo "Using role: $LAMBDA_ROLE_ARN"
else
    echo "✅ Lambda function exists"
    LAMBDA_ROLE_ARN=$(echo $LAMBDA_EXISTS | jq -r '.Configuration.Role')
fi

# Check CloudWatch logs to see what's causing the error
echo "📋 Step 2: Checking recent CloudWatch logs..."

LOG_GROUP="/aws/lambda/devops-bootcamp-containers"

# Check if log group exists
LOG_GROUP_EXISTS=$(aws logs describe-log-groups --log-group-name-prefix $LOG_GROUP 2>/dev/null | jq -r '.logGroups | length')

if [ "$LOG_GROUP_EXISTS" -gt 0 ]; then
    echo "📊 Recent error logs:"
    
    # Get the latest log stream
    LATEST_STREAM=$(aws logs describe-log-streams \
      --log-group-name $LOG_GROUP \
      --order-by LastEventTime \
      --descending \
      --limit 1 \
      --query 'logStreams[0].logStreamName' \
      --output text 2>/dev/null)
    
    if [ "$LATEST_STREAM" != "None" ] && [ "$LATEST_STREAM" != "" ]; then
        echo "Latest log stream: $LATEST_STREAM"
        
        # Get recent log events
        aws logs get-log-events \
          --log-group-name $LOG_GROUP \
          --log-stream-name "$LATEST_STREAM" \
          --start-time $(echo "$(date +%s) - 300" | bc)000 \
          --query 'events[*].message' \
          --output text 2>/dev/null | tail -10
    else
        echo "No recent log streams found"
    fi
else
    echo "No log group found - Lambda may not have been invoked yet"
fi

# Create a completely fresh, minimal Lambda function
echo "📋 Step 3: Creating minimal container Lambda..."

mkdir -p fresh-lambda
cat > fresh-lambda/index.js << 'EOF'
// Minimal container management Lambda - designed to work with API Gateway
exports.handler = async (event, context) => {
    // Log the incoming event for debugging
    console.log('=== CONTAINER LAMBDA START ===');
    console.log('Event received:', JSON.stringify(event, null, 2));
    console.log('Context:', JSON.stringify(context, null, 2));
    
    // Standard CORS headers
    const corsHeaders = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    };
    
    try {
        // Handle OPTIONS (preflight) requests
        if (event.httpMethod === 'OPTIONS') {
            console.log('Handling OPTIONS request');
            return {
                statusCode: 200,
                headers: corsHeaders,
                body: ''
            };
        }
        
        // Parse request body
        let requestBody = {};
        if (event.body) {
            try {
                requestBody = JSON.parse(event.body);
                console.log('Parsed request body:', requestBody);
            } catch (parseError) {
                console.error('Error parsing request body:', parseError);
                return {
                    statusCode: 400,
                    headers: corsHeaders,
                    body: JSON.stringify({
                        error: 'Invalid JSON in request body',
                        details: parseError.message
                    })
                };
            }
        }
        
        const { action, userId, challengeId, sessionId } = requestBody;
        
        console.log('Processing action:', action);
        console.log('User ID:', userId);
        console.log('Challenge ID:', challengeId);
        console.log('Session ID:', sessionId);
        
        // Handle different actions
        let response;
        
        switch (action) {
            case 'launch':
                console.log('Launching container...');
                response = {
                    sessionId: `demo-session-${Date.now()}`,
                    status: 'PROVISIONING',
                    message: 'Container launch initiated (demo mode)',
                    challengeId: challengeId,
                    userId: userId,
                    timestamp: new Date().toISOString()
                };
                break;
                
            case 'status':
                console.log('Checking status for session:', sessionId);
                response = {
                    sessionId: sessionId || 'demo-session',
                    status: 'RUNNING',
                    publicIp: '203.0.113.1',
                    sshCommand: 'ssh student@203.0.113.1',
                    password: 'devops123',
                    expiresIn: 7200,
                    message: 'Demo container running',
                    timestamp: new Date().toISOString()
                };
                break;
                
            case 'terminate':
                console.log('Terminating session:', sessionId);
                response = {
                    sessionId: sessionId,
                    status: 'TERMINATED',
                    message: 'Container terminated successfully (demo mode)',
                    timestamp: new Date().toISOString()
                };
                break;
                
            default:
                console.log('Invalid action received:', action);
                return {
                    statusCode: 400,
                    headers: corsHeaders,
                    body: JSON.stringify({
                        error: 'Invalid action',
                        validActions: ['launch', 'status', 'terminate'],
                        receivedAction: action
                    })
                };
        }
        
        console.log('Sending response:', response);
        
        return {
            statusCode: 200,
            headers: corsHeaders,
            body: JSON.stringify(response)
        };
        
    } catch (error) {
        console.error('=== LAMBDA ERROR ===');
        console.error('Error type:', error.constructor.name);
        console.error('Error message:', error.message);
        console.error('Error stack:', error.stack);
        
        return {
            statusCode: 500,
            headers: corsHeaders,
            body: JSON.stringify({
                error: 'Internal server error',
                message: error.message,
                type: error.constructor.name,
                timestamp: new Date().toISOString()
            })
        };
    } finally {
        console.log('=== CONTAINER LAMBDA END ===');
    }
};
EOF

cat > fresh-lambda/package.json << 'EOF'
{
  "name": "container-lambda",
  "version": "1.0.0",
  "description": "Container management Lambda for DevOps Bootcamp",
  "main": "index.js",
  "dependencies": {}
}
EOF

cd fresh-lambda
zip -r function.zip .

echo "📋 Step 4: Deploying fresh Lambda function..."

# Try to update existing function first
UPDATE_RESULT=$(aws lambda update-function-code \
  --function-name devops-bootcamp-containers \
  --zip-file fileb://function.zip 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Lambda function updated successfully"
else
    echo "⚠️ Update failed, creating new function..."
    
    # Create new function
    CREATE_RESULT=$(aws lambda create-function \
      --function-name devops-bootcamp-containers \
      --runtime nodejs18.x \
      --role $LAMBDA_ROLE_ARN \
      --handler index.handler \
      --zip-file fileb://function.zip \
      --timeout 30 \
      --memory-size 128 \
      --description "Container management for DevOps Bootcamp" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "✅ Lambda function created successfully"
    else
        echo "❌ Failed to create Lambda function"
        cd ..
        rm -rf fresh-lambda
        exit 1
    fi
fi

cd ..
rm -rf fresh-lambda

# Test the Lambda function directly
echo "📋 Step 5: Testing Lambda function directly..."

cat > direct-test.json << 'EOF'
{
  "httpMethod": "POST",
  "path": "/api/containers",
  "headers": {
    "Content-Type": "application/json"
  },
  "body": "{\"action\": \"launch\", \"userId\": \"test-user\", \"challengeId\": \"welcome-01\"}"
}
EOF

echo "Testing Lambda directly..."
aws lambda invoke \
  --function-name devops-bootcamp-containers \
  --payload file://direct-test.json \
  --cli-binary-format raw-in-base64-out \
  direct-response.json

echo "Direct Lambda test result:"
cat direct-response.json | jq . 2>/dev/null || cat direct-response.json

# Wait a moment then test via API Gateway
echo "📋 Step 6: Testing via API Gateway..."
sleep 3

API_TEST=$(curl -s -X POST "$API_ENDPOINT/api/containers" \
  -H "Content-Type: application/json" \
  -d '{"action": "launch", "userId": "test", "challengeId": "test"}')

echo "API Gateway test result:"
echo $API_TEST | jq . 2>/dev/null || echo $API_TEST

# Check if it worked
if echo $API_TEST | grep -q "demo-session"; then
    echo "✅ SUCCESS! Container API is now working"
    
    # Test all three actions
    echo "📋 Testing all container actions..."
    
    echo "1. Launch:"
    curl -s -X POST "$API_ENDPOINT/api/containers" \
      -H "Content-Type: application/json" \
      -d '{"action": "launch", "userId": "test", "challengeId": "welcome"}' | jq .
    
    echo "2. Status:"
    curl -s -X POST "$API_ENDPOINT/api/containers" \
      -H "Content-Type: application/json" \
      -d '{"action": "status", "sessionId": "test-session"}' | jq .
    
    echo "3. Terminate:"
    curl -s -X POST "$API_ENDPOINT/api/containers" \
      -H "Content-Type: application/json" \
      -d '{"action": "terminate", "sessionId": "test-session"}' | jq .
      
else
    echo "❌ Container API still not working"
    
    # Check CloudWatch logs again
    echo "📊 Checking latest logs after update..."
    sleep 5
    
    LATEST_STREAM=$(aws logs describe-log-streams \
      --log-group-name $LOG_GROUP \
      --order-by LastEventTime \
      --descending \
      --limit 1 \
      --query 'logStreams[0].logStreamName' \
      --output text 2>/dev/null)
    
    if [ "$LATEST_STREAM" != "None" ] && [ "$LATEST_STREAM" != "" ]; then
        echo "Latest error logs:"
        aws logs get-log-events \
          --log-group-name $LOG_GROUP \
          --log-stream-name "$LATEST_STREAM" \
          --start-time $(echo "$(date +%s) - 60" | bc)000 \
          --query 'events[*].message' \
          --output text 2>/dev/null | tail -5
    fi
fi

# Clean up
rm -f direct-test.json direct-response.json lambda-trust-policy.json

echo ""
echo "🔍 DEBUGGING COMPLETE"
echo "===================="
echo ""
echo "📋 Summary:"
echo "   - Lambda function updated with extensive logging"
echo "   - Direct Lambda test completed"
echo "   - API Gateway integration tested"
echo ""
echo "🔗 Next steps:"
echo "   1. Check the container test page: $CLOUDFRONT_URL/container-test.html"
echo "   2. If still failing, check CloudWatch logs at:"
echo "      https://console.aws.amazon.com/cloudwatch/home?region=$REGION#logStream:group=/aws/lambda/devops-bootcamp-containers"
echo ""
echo "💡 The Lambda now has extensive logging to help identify any remaining issues."
echo ""
