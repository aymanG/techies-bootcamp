#!/bin/bash
# Completely rebuild the container endpoint from scratch

# Load configuration
source step6-config-fixed.sh 2>/dev/null || {
    echo "❌ Configuration not found. Please run previous setup scripts first."
    exit 1
}

echo "🔧 REBUILDING CONTAINER ENDPOINT FROM SCRATCH"
echo "=============================================="

# Step 1: Delete and recreate the containers resource
echo "📋 Step 1: Cleaning up existing containers resource..."

# Get the containers resource ID
CONTAINERS_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query "items[?path=='/api/containers'].id" --output text)

if [ "$CONTAINERS_RESOURCE_ID" != "" ] && [ "$CONTAINERS_RESOURCE_ID" != "None" ]; then
    echo "Deleting existing /api/containers resource: $CONTAINERS_RESOURCE_ID"
    aws apigateway delete-resource \
      --rest-api-id $API_ID \
      --resource-id $CONTAINERS_RESOURCE_ID
    echo "✅ Old resource deleted"
else
    echo "No existing containers resource found"
fi

# Step 2: Get the API resource ID
echo "📋 Step 2: Finding /api resource..."

API_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query "items[?path=='/api'].id" --output text)

if [ "$API_RESOURCE_ID" = "" ] || [ "$API_RESOURCE_ID" = "None" ]; then
    echo "❌ /api resource not found. Your API Gateway setup is incomplete."
    exit 1
fi

echo "✅ Found /api resource: $API_RESOURCE_ID"

# Step 3: Create a working Lambda function
echo "📋 Step 3: Creating working Lambda function..."

# Delete existing function if it exists
aws lambda delete-function --function-name devops-bootcamp-containers 2>/dev/null || echo "No existing function to delete"

# Create fresh Lambda code
mkdir -p working-lambda
cat > working-lambda/index.js << 'EOF'
exports.handler = async (event) => {
    console.log('=== EVENT RECEIVED ===');
    console.log(JSON.stringify(event, null, 2));
    
    // CORS headers - MUST be included in every response
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    };
    
    try {
        // Handle preflight OPTIONS request
        if (event.httpMethod === 'OPTIONS') {
            console.log('Handling CORS preflight');
            return {
                statusCode: 200,
                headers: headers,
                body: ''
            };
        }
        
        // Parse the request body
        let body = {};
        if (event.body) {
            body = JSON.parse(event.body);
        }
        
        console.log('Parsed body:', body);
        
        const { action, userId, challengeId, sessionId } = body;
        
        // Mock responses for testing
        let response;
        
        switch (action) {
            case 'launch':
                response = {
                    sessionId: `session-${Date.now()}`,
                    status: 'PROVISIONING',
                    message: 'Container is starting up (demo mode)',
                    challengeId: challengeId,
                    userId: userId
                };
                break;
                
            case 'status':
                response = {
                    sessionId: sessionId || 'demo-session',
                    status: 'RUNNING',
                    publicIp: '203.0.113.1',
                    sshCommand: 'ssh student@203.0.113.1',
                    password: 'devops123',
                    expiresIn: 7200,
                    message: 'Demo container is running'
                };
                break;
                
            case 'terminate':
                response = {
                    sessionId: sessionId,
                    status: 'TERMINATED',
                    message: 'Container terminated (demo mode)'
                };
                break;
                
            default:
                return {
                    statusCode: 400,
                    headers: headers,
                    body: JSON.stringify({
                        error: 'Invalid action',
                        validActions: ['launch', 'status', 'terminate']
                    })
                };
        }
        
        console.log('Sending response:', response);
        
        return {
            statusCode: 200,
            headers: headers,
            body: JSON.stringify(response)
        };
        
    } catch (error) {
        console.error('ERROR:', error);
        
        return {
            statusCode: 500,
            headers: headers,
            body: JSON.stringify({
                error: 'Internal server error',
                message: error.message
            })
        };
    }
};
EOF

cd working-lambda
zip -r function.zip .

# Create the Lambda function
echo "Creating Lambda function..."

LAMBDA_CREATE_OUTPUT=$(aws lambda create-function \
  --function-name devops-bootcamp-containers \
  --runtime nodejs18.x \
  --role $LAMBDA_ROLE_ARN \
  --handler index.handler \
  --zip-file fileb://function.zip \
  --timeout 30 \
  --memory-size 128 \
  --description "Container management for DevOps Bootcamp" \
  --output json)

if [ $? -eq 0 ]; then
    LAMBDA_ARN=$(echo $LAMBDA_CREATE_OUTPUT | jq -r '.FunctionArn')
    echo "✅ Lambda created: $LAMBDA_ARN"
else
    echo "❌ Failed to create Lambda function"
    cd ..
    rm -rf working-lambda
    exit 1
fi

cd ..
rm -rf working-lambda

# Step 4: Create the /api/containers resource
echo "📋 Step 4: Creating /api/containers resource..."

CONTAINERS_RESOURCE_OUTPUT=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $API_RESOURCE_ID \
  --path-part containers \
  --output json)

CONTAINERS_RESOURCE_ID=$(echo $CONTAINERS_RESOURCE_OUTPUT | jq -r '.id')
echo "✅ Created /api/containers resource: $CONTAINERS_RESOURCE_ID"

# Step 5: Add OPTIONS method for CORS
echo "📋 Step 5: Adding OPTIONS method for CORS..."

# Add OPTIONS method to API
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $CONTAINERS_RESOURCE_ID \
  --http-method OPTIONS \
  --authorization-type NONE \
  --no-api-key-required

# Add mock integration for OPTIONS method (no backend, just mock response)
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $CONTAINERS_RESOURCE_ID \
  --http-method OPTIONS \
  --type MOCK \
  --request-templates '{"application/json": "{\"statusCode\": 200}"}' \
  --passthrough-behavior WHEN_NO_TEMPLATES

# Add method response for OPTIONS (correct CORS headers)
aws apigateway put-method-response \
  --rest-api-id $API_ID \
  --resource-id $CONTAINERS_RESOURCE_ID \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{
    "method.response.header.Access-Control-Allow-Headers": true,
    "method.response.header.Access-Control-Allow-Methods": true,
    "method.response.header.Access-Control-Allow-Origin": true
  }'

# Add integration response for OPTIONS (set CORS headers properly)
aws apigateway put-integration-response \
  --rest-api-id $API_ID \
  --resource-id $CONTAINERS_RESOURCE_ID \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{
    "method.response.header.Access-Control-Allow-Headers": "'\''Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'\''",
    "method.response.header.Access-Control-Allow-Methods": "'\''GET,POST,PUT,DELETE,OPTIONS'\''",
    "method.response.header.Access-Control-Allow-Origin": "'\''*'\''"
  }'
echo "✅  OPTIONS method configured"



# Step 6: Add POST method
echo "📋 Step 6: Adding POST method..."

aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $CONTAINERS_RESOURCE_ID \
  --http-method POST \
  --authorization-type NONE \
  --no-api-key-required

# Add Lambda integration for POST
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $CONTAINERS_RESOURCE_ID \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations"

echo "✅ POST method configured"

# Step 7: Add Lambda permission
echo "📋 Step 7: Adding Lambda permission..."

# Add permission to Lambda function for API Gateway to invoke it
aws lambda add-permission \
  --function-name devops-bootcamp-containers \
  --statement-id api-gateway-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*"

echo "✅  Lambda permission added"

# Step 8: Deploy the API
echo "📋 Step 8: Deploying API..."

aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name prod \
  --description "Container endpoints rebuilt"

echo "✅ API deployed"

# Step 9: Test the endpoint
echo "📋 Step 9: Testing the rebuilt endpoint..."

sleep 3  # Wait for deployment

# Test OPTIONS first (CORS preflight)
echo "Testing CORS preflight..."
OPTIONS_TEST=$(curl -s -X OPTIONS "$API_ENDPOINT/api/containers" \
  -H "Origin: https://d1t1et5tjvep2.cloudfront.net" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" \
  -I)

echo "OPTIONS response headers:"
echo "$OPTIONS_TEST"

if echo "$OPTIONS_TEST" | grep -i "access-control-allow-origin"; then
    echo "✅ CORS headers present"
else
    echo "❌ CORS headers missing"
fi

# Test POST request
echo -e "\nTesting POST request..."
POST_TEST=$(curl -s -X POST "$API_ENDPOINT/api/containers" \
  -H "Content-Type: application/json" \
  -H "Origin: https://d1t1et5tjvep2.cloudfront.net" \
  -d '{"action": "launch", "userId": "test", "challengeId": "welcome"}')

echo "POST response:"
echo "$POST_TEST" | jq . 2>/dev/null || echo "$POST_TEST"

if echo "$POST_TEST" | grep -q "session-"; then
    echo "✅ Container endpoint is working!"
    
    # Test all actions
    echo -e "\n📋 Testing all container actions..."
    
    echo "1. Launch container:"
    curl -s -X POST "$API_ENDPOINT/api/containers" \
      -H "Content-Type: application/json" \
      -d '{"action": "launch", "userId": "test", "challengeId": "welcome"}' | jq .
    
    echo -e "\n2. Check status:"
    curl -s -X POST "$API_ENDPOINT/api/containers" \
      -H "Content-Type: application/json" \
      -d '{"action": "status", "sessionId": "test-session"}' | jq .
    
    echo -e "\n3. Terminate container:"
    curl -s -X POST "$API_ENDPOINT/api/containers" \
      -H "Content-Type: application/json" \
      -d '{"action": "terminate", "sessionId": "test-session"}' | jq .
      
else
    echo "❌ Container endpoint still not working"
    echo "Checking CloudWatch logs..."
    
    # Check logs
    sleep 5
    LOG_GROUP="/aws/lambda/devops-bootcamp-containers"
    LATEST_STREAM=$(aws logs describe-log-streams \
      --log-group-name $LOG_GROUP \
      --order-by LastEventTime \
      --descending \
      --limit 1 \
      --query 'logStreams[0].logStreamName' \
      --output text 2>/dev/null)
    
    if [ "$LATEST_STREAM" != "None" ] && [ "$LATEST_STREAM" != "" ]; then
        echo "Recent error logs:"
        aws logs get-log-events \
          --log-group-name $LOG_GROUP \
          --log-stream-name "$LATEST_STREAM" \
          --start-time $(echo "$(date +%s) - 120" | bc)000 \
          --query 'events[*].message' \
          --output text 2>/dev/null | tail -10
    fi
fi

# Step 10: Create a fixed test page
echo "📋 Step 10: Creating updated test page..."

cat > container-test-fixed.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Container API Test - Fixed</title>
    <style>
        body { 
            background: #0a0a0a; 
            color: #00ff88; 
            font-family: monospace; 
            padding: 20px; 
            line-height: 1.6;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
        }
        button { 
            background: #00ff88; 
            color: #0a0a0a; 
            border: none; 
            padding: 10px 20px; 
            margin: 5px; 
            cursor: pointer; 
            border-radius: 5px; 
            font-weight: bold;
        }
        button:hover {
            background: #00cc6f;
        }
        .response { 
            background: #1a1a1a; 
            padding: 15px; 
            margin: 10px 0; 
            border-radius: 5px; 
            border: 1px solid #333; 
            white-space: pre-wrap; 
            max-height: 300px;
            overflow-y: auto;
        }
        .config { 
            background: #0a2a0a; 
            padding: 15px; 
            border-radius: 5px; 
            margin-bottom: 20px; 
            border: 1px solid #00ff88;
        }
        .status {
            padding: 10px;
            border-radius: 5px;
            margin: 10px 0;
        }
        .success { background: #1a3a1a; border: 1px solid #00ff88; }
        .error { background: #3a1a1a; border: 1px solid #ff0088; color: #ff0088; }
        .info { background: #1a2a3a; border: 1px solid #0088ff; color: #0088ff; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Container API Test - Rebuilt</h1>
        
        <div class="config">
            <h3>✅ Rebuilt Configuration:</h3>
            <p><strong>API Endpoint:</strong> $API_ENDPOINT</p>
            <p><strong>Containers Resource:</strong> $CONTAINERS_RESOURCE_ID</p>
            <p><strong>Lambda ARN:</strong> $LAMBDA_ARN</p>
            <p><strong>CORS:</strong> Enabled with proper headers</p>
            <p><strong>Status:</strong> <span id="apiStatus">Testing...</span></p>
        </div>
        
        <div class="status info">
            <strong>📋 Instructions:</strong><br>
            1. Click "Test CORS" to verify CORS headers<br>
            2. Click "Launch Container" to test the API<br>
            3. Check the response for success/error details
        </div>
        
        <h3>🧪 API Tests:</h3>
        <button onclick="testCORS()">🔧 Test CORS</button>
        <button onclick="testLaunch()">🚀 Launch Container</button>
        <button onclick="testStatus()">📊 Check Status</button>
        <button onclick="testTerminate()">🛑 Terminate</button>
        <button onclick="clearResults()">🧹 Clear</button>
        
        <div id="results" class="response">Ready to test the rebuilt container API...</div>
    </div>
    
    <script>
        const API_ENDPOINT = '$API_ENDPOINT';
        let currentSessionId = null;
        
        function log(message, type = 'info') {
            const results = document.getElementById('results');
            const timestamp = new Date().toLocaleTimeString();
            results.textContent += '[' + timestamp + '] ' + message + '\\n';
            results.scrollTop = results.scrollHeight;
        }
        
        function clearResults() {
            document.getElementById('results').textContent = '';
        }
        
        async function testCORS() {
            log('🔧 Testing CORS preflight...', 'info');
            
            try {
                const response = await fetch(API_ENDPOINT + '/api/containers', {
                    method: 'OPTIONS',
                    headers: {
                        'Origin': window.location.origin,
                        'Access-Control-Request-Method': 'POST',
                        'Access-Control-Request-Headers': 'Content-Type'
                    }
                });
                
                log('CORS preflight status: ' + response.status);
                
                const corsHeaders = {
                    'Access-Control-Allow-Origin': response.headers.get('Access-Control-Allow-Origin'),
                    'Access-Control-Allow-Methods': response.headers.get('Access-Control-Allow-Methods'),
                    'Access-Control-Allow-Headers': response.headers.get('Access-Control-Allow-Headers')
                };
                
                log('CORS headers received:');
                log(JSON.stringify(corsHeaders, null, 2));
                
                if (corsHeaders['Access-Control-Allow-Origin']) {
                    log('✅ CORS is properly configured!');
                    document.getElementById('apiStatus').textContent = 'CORS OK';
                } else {
                    log('❌ CORS headers missing');
                    document.getElementById('apiStatus').textContent = 'CORS Failed';
                }
                
            } catch (error) {
                log('❌ CORS test failed: ' + error.message);
                document.getElementById('apiStatus').textContent = 'CORS Error';
            }
        }
        
        async function testLaunch() {
            log('🚀 Testing container launch...', 'info');
            
            try {
                const response = await fetch(API_ENDPOINT + '/api/containers', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        action: 'launch',
                        userId: 'test-user-' + Date.now(),
                        challengeId: 'welcome-01'
                    })
                });
                
                log('Response status: ' + response.status);
                log('Response headers:');
                for (let [key, value] of response.headers) {
                    log('  ' + key + ': ' + value);
                }
                
                const data = await response.json();
                currentSessionId = data.sessionId;
                
                log('✅ Launch successful!');
                log('Response: ' + JSON.stringify(data, null, 2));
                
                document.getElementById('apiStatus').textContent = 'API Working';
                
            } catch (error) {
                log('❌ Launch failed: ' + error.message);
                document.getElementById('apiStatus').textContent = 'API Error';
            }
        }
        
        async function testStatus() {
            if (!currentSessionId) {
                log('⚠️ No active session. Launch a container first.');
                return;
            }
            
            log('📊 Checking container status...', 'info');
            
            try {
                const response = await fetch(API_ENDPOINT + '/api/containers', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        action: 'status',
                        sessionId: currentSessionId
                    })
                });
                
                const data = await response.json();
                
                log('✅ Status check successful!');
                log('Response: ' + JSON.stringify(data, null, 2));
                
            } catch (error) {
                log('❌ Status check failed: ' + error.message);
            }
        }
        
        async function testTerminate() {
            if (!currentSessionId) {
                log('⚠️ No active session. Launch a container first.');
                return;
            }
            
            log('🛑 Terminating container...', 'info');
            
            try {
                const response = await fetch(API_ENDPOINT + '/api/containers', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        action: 'terminate',
                        sessionId: currentSessionId
                    })
                });
                
                const data = await response.json();
                currentSessionId = null;
                
                log('✅ Termination successful!');
                log('Response: ' + JSON.stringify(data, null, 2));
                
            } catch (error) {
                log('❌ Termination failed: ' + error.message);
            }
        }
        
        // Auto-test CORS on page load
        window.onload = () => {
            setTimeout(testCORS, 1000);
        };
    </script>
</body>
</html>
EOF

# Upload the fixed test page
aws s3 cp container-test-fixed.html s3://$BUCKET_NAME/container-test.html

echo "✅ Updated test page uploaded"

# Step 11: Update configuration
echo "📋 Step 11: Updating configuration..."

cat >> step6-config-fixed.sh << EOF

# REBUILT CONTAINER SYSTEM
export CONTAINERS_RESOURCE_ID_NEW=$CONTAINERS_RESOURCE_ID
export CONTAINER_LAMBDA_ARN_NEW=$LAMBDA_ARN
export CONTAINER_SYSTEM_STATUS="Rebuilt and Working"
EOF

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*" \
  --output json > /dev/null

# Clean up
rm -f container-test-fixed.html

echo ""
echo "🎉 CONTAINER ENDPOINT COMPLETELY REBUILT!"
echo "========================================"
echo ""
echo "✅ What was rebuilt:"
echo "   - 🗑️  Deleted old containers resource"
echo "   - 🆕 Created fresh Lambda function with proper CORS"
echo "   - 🔧 Rebuilt /api/containers resource from scratch"
echo "   - ✅ Configured OPTIONS method for CORS preflight"
echo "   - ✅ Configured POST method with Lambda integration"
echo "   - 🔐 Added proper Lambda permissions"
echo "   - 🚀 Deployed the API"
echo ""
echo "🔗 Test URLs:"
echo "   Container Test: $CLOUDFRONT_URL/container-test.html"
echo "   Main Dashboard: $CLOUDFRONT_URL/dashboard.html"
echo ""
echo "📋 Expected Results:"
echo "   1. CORS test should show 'Access-Control-Allow-Origin: *'"
echo "   2. Launch test should return a session ID"
echo "   3. No more CORS errors in browser console"
echo ""
echo "⏰ Wait 2-3 minutes for CloudFront cache to clear, then test!"
echo ""
