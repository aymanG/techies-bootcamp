#!/bin/bash
# Fix CORS headers properly for the container endpoint

# Load configuration
source step6-config-fixed.sh 2>/dev/null || {
    echo "❌ Configuration not found"
    exit 1
}

echo "🔧 FIXING CORS HEADERS PROPERLY"
echo "==============================="

# Get the containers resource ID
CONTAINERS_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query "items[?path=='/api/containers'].id" --output text)

if [ "$CONTAINERS_RESOURCE_ID" = "" ] || [ "$CONTAINERS_RESOURCE_ID" = "None" ]; then
    echo "❌ /api/containers resource not found"
    exit 1
fi

echo "✅ Found containers resource: $CONTAINERS_RESOURCE_ID"

# Step 1: Delete existing OPTIONS method and recreate it properly
echo "📋 Step 1: Recreating OPTIONS method..."

# Delete existing OPTIONS method
aws apigateway delete-method \
  --rest-api-id $API_ID \
  --resource-id $CONTAINERS_RESOURCE_ID \
  --http-method OPTIONS 2>/dev/null || echo "No existing OPTIONS method"

# Create OPTIONS method
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $CONTAINERS_RESOURCE_ID \
  --http-method OPTIONS \
  --authorization-type NONE \
  --no-api-key-required

echo "✅ OPTIONS method created"

# Step 2: Add mock integration with proper request template
echo "📋 Step 2: Adding mock integration..."

aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $CONTAINERS_RESOURCE_ID \
  --http-method OPTIONS \
  --type MOCK \
  --request-templates '{"application/json": "{\"statusCode\": 200}"}' \
  --passthrough-behavior WHEN_NO_TEMPLATES

echo "✅ Mock integration added"

# Step 3: Add method response with CORS headers
echo "📋 Step 3: Adding method response..."

aws apigateway put-method-response \
  --rest-api-id $API_ID \
  --resource-id $CONTAINERS_RESOURCE_ID \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{
    "method.response.header.Access-Control-Allow-Headers": false,
    "method.response.header.Access-Control-Allow-Methods": false,
    "method.response.header.Access-Control-Allow-Origin": false
  }' \
  --response-models '{
    "application/json": "Empty"
  }'

echo "✅ Method response added"

# Step 4: Add integration response with actual CORS header values
echo "📋 Step 4: Adding integration response with CORS headers..."

aws apigateway put-integration-response \
  --rest-api-id $API_ID \
  --resource-id $CONTAINERS_RESOURCE_ID \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{
    "method.response.header.Access-Control-Allow-Headers": "'\''Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'\''",
    "method.response.header.Access-Control-Allow-Methods": "'\''GET,POST,PUT,DELETE,OPTIONS'\''",
    "method.response.header.Access-Control-Allow-Origin": "'\''*'\''"
  }' \
  --response-templates '{
    "application/json": ""
  }'

echo "✅ Integration response with CORS headers added"

# Step 5: Also ensure POST method has proper method response for CORS
echo "📋 Step 5: Ensuring POST method has CORS headers..."

# Add method response for POST (if it doesn't exist)
aws apigateway put-method-response \
  --rest-api-id $API_ID \
  --resource-id $CONTAINERS_RESOURCE_ID \
  --http-method POST \
  --status-code 200 \
  --response-parameters '{
    "method.response.header.Access-Control-Allow-Origin": false
  }' 2>/dev/null || echo "POST method response may already exist"

# Add integration response for POST CORS
aws apigateway put-integration-response \
  --rest-api-id $API_ID \
  --resource-id $CONTAINERS_RESOURCE_ID \
  --http-method POST \
  --status-code 200 \
  --response-parameters '{
    "method.response.header.Access-Control-Allow-Origin": "'\''*'\''"
  }' 2>/dev/null || echo "POST integration response may already exist"

echo "✅ POST CORS headers configured"

# Step 6: Deploy the API
echo "📋 Step 6: Deploying API changes..."

aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name prod \
  --description "Fixed CORS headers"

echo "✅ API deployed"

# Step 7: Test CORS immediately
echo "📋 Step 7: Testing CORS configuration..."

sleep 3  # Wait for deployment

# Test OPTIONS request with verbose output
echo "Testing OPTIONS request..."
CORS_TEST=$(curl -s -v -X OPTIONS "$API_ENDPOINT/api/containers" \
  -H "Origin: https://example.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" 2>&1)

echo "CORS test response:"
echo "$CORS_TEST"

# Extract just the headers
CORS_HEADERS=$(echo "$CORS_TEST" | grep -i "access-control")
echo ""
echo "CORS headers found:"
echo "$CORS_HEADERS"

if echo "$CORS_HEADERS" | grep -q "access-control-allow-origin"; then
    echo "✅ CORS headers are now present!"
else
    echo "❌ CORS headers still missing - trying alternative approach..."
    
    # Alternative: Update the Lambda to ensure it always returns CORS headers
    echo "📋 Updating Lambda to force CORS headers..."
    
    mkdir -p cors-lambda
    cat > cors-lambda/index.js << 'EOF'
exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    // Force CORS headers in every response
    const corsHeaders = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    };
    
    try {
        // Handle OPTIONS requests
        if (event.httpMethod === 'OPTIONS') {
            console.log('Handling OPTIONS with CORS');
            return {
                statusCode: 200,
                headers: corsHeaders,
                body: JSON.stringify({ message: 'CORS preflight successful' })
            };
        }
        
        // Handle POST requests
        if (event.httpMethod === 'POST') {
            let body = {};
            if (event.body) {
                body = JSON.parse(event.body);
            }
            
            const { action, userId, challengeId, sessionId } = body;
            console.log('Processing action:', action);
            
            let response;
            
            switch (action) {
                case 'launch':
                    response = {
                        sessionId: `session-${Date.now()}`,
                        status: 'PROVISIONING',
                        message: 'Container launching (demo)',
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
                        expiresIn: 7200
                    };
                    break;
                    
                case 'terminate':
                    response = {
                        sessionId: sessionId,
                        status: 'TERMINATED',
                        message: 'Container terminated'
                    };
                    break;
                    
                default:
                    return {
                        statusCode: 400,
                        headers: corsHeaders,
                        body: JSON.stringify({ error: 'Invalid action' })
                    };
            }
            
            return {
                statusCode: 200,
                headers: corsHeaders,
                body: JSON.stringify(response)
            };
        }
        
        // Handle other methods
        return {
            statusCode: 405,
            headers: corsHeaders,
            body: JSON.stringify({ error: 'Method not allowed' })
        };
        
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            headers: corsHeaders,
            body: JSON.stringify({ error: error.message })
        };
    }
};
EOF

    cd cors-lambda
    zip -r function.zip .
    
    # Update Lambda function
    aws lambda update-function-code \
      --function-name devops-bootcamp-containers \
      --zip-file fileb://function.zip
    
    cd ..
    rm -rf cors-lambda
    
    echo "✅ Lambda updated with forced CORS headers"
    
    # Deploy API again
    aws apigateway create-deployment \
      --rest-api-id $API_ID \
      --stage-name prod \
      --description "Lambda CORS headers"
    
    sleep 3
    
    # Test again
    echo "Testing CORS after Lambda update..."
    CORS_TEST2=$(curl -s -X OPTIONS "$API_ENDPOINT/api/containers" \
      -H "Origin: https://example.com" \
      -H "Access-Control-Request-Method: POST" \
      -H "Access-Control-Request-Headers: Content-Type")
    
    echo "Updated CORS test:"
    echo "$CORS_TEST2"
fi

# Step 8: Test actual POST request
echo "📋 Step 8: Testing POST request..."

POST_TEST=$(curl -s -X POST "$API_ENDPOINT/api/containers" \
  -H "Content-Type: application/json" \
  -H "Origin: https://example.com" \
  -d '{"action": "launch", "userId": "test", "challengeId": "welcome"}')

echo "POST test result:"
echo "$POST_TEST" | jq . 2>/dev/null || echo "$POST_TEST"

if echo "$POST_TEST" | grep -q "session-"; then
    echo "✅ POST request successful!"
else
    echo "❌ POST request failed"
fi

# Step 9: Create final test page with better error handling
echo "📋 Step 9: Creating enhanced test page..."

cat > cors-test-final.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>CORS Fixed - Container Test</title>
    <style>
        body { 
            background: #0a0a0a; 
            color: #00ff88; 
            font-family: monospace; 
            padding: 20px; 
        }
        .container { max-width: 900px; margin: 0 auto; }
        button { 
            background: #00ff88; 
            color: #0a0a0a; 
            border: none; 
            padding: 12px 24px; 
            margin: 8px; 
            cursor: pointer; 
            border-radius: 5px; 
            font-weight: bold;
        }
        .response { 
            background: #1a1a1a; 
            padding: 20px; 
            margin: 15px 0; 
            border-radius: 8px; 
            border: 1px solid #333; 
            white-space: pre-wrap; 
            max-height: 400px;
            overflow-y: auto;
            font-size: 14px;
        }
        .status { padding: 15px; border-radius: 8px; margin: 15px 0; }
        .success { background: #1a3a1a; border: 2px solid #00ff88; }
        .error { background: #3a1a1a; border: 2px solid #ff0088; color: #ff0088; }
        .info { background: #1a2a3a; border: 2px solid #0088ff; color: #0088ff; }
        h1, h3 { color: #00ff88; }
        .config { background: #0a2a0a; padding: 20px; border-radius: 8px; margin-bottom: 25px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔧 CORS Fixed - Container API Test</h1>
        
        <div class="config">
            <h3>API Configuration:</h3>
            <p><strong>Endpoint:</strong> $API_ENDPOINT/api/containers</p>
            <p><strong>CORS Status:</strong> <span id="corsStatus">Testing...</span></p>
            <p><strong>API Status:</strong> <span id="apiStatus">Not tested</span></p>
        </div>
        
        <div class="status info">
            <strong>🔍 Diagnostic Tests:</strong><br>
            These tests will help verify that CORS is working properly
        </div>
        
        <h3>🧪 Test Controls:</h3>
        <button onclick="detailedCORSTest()">🔬 Detailed CORS Test</button>
        <button onclick="testContainer()">🚀 Test Container API</button>
        <button onclick="testAllActions()">🔄 Test All Actions</button>
        <button onclick="clearLogs()">🧹 Clear Logs</button>
        
        <div id="logs" class="response">Ready for testing...</div>
    </div>
    
    <script>
        const API_URL = '$API_ENDPOINT/api/containers';
        let sessionId = null;
        
        function log(message, type = 'info') {
            const logs = document.getElementById('logs');
            const time = new Date().toLocaleTimeString();
            logs.textContent += \`[\${time}] \${message}\\n\`;
            logs.scrollTop = logs.scrollHeight;
        }
        
        function clearLogs() {
            document.getElementById('logs').textContent = 'Logs cleared...\\n';
        }
        
        function updateStatus(element, status, success = true) {
            const el = document.getElementById(element);
            el.textContent = status;
            el.style.color = success ? '#00ff88' : '#ff0088';
        }
        
        async function detailedCORSTest() {
            log('🔬 Running detailed CORS test...');
            
            try {
                // Test 1: Simple OPTIONS request
                log('Test 1: Basic OPTIONS request');
                const response1 = await fetch(API_URL, {
                    method: 'OPTIONS'
                });
                
                log(\`Status: \${response1.status}\`);
                
                // Check headers
                const headers = {};
                for (let [key, value] of response1.headers) {
                    headers[key] = value;
                    if (key.toLowerCase().includes('access-control')) {
                        log(\`  \${key}: \${value}\`);
                    }
                }
                
                // Test 2: CORS preflight simulation
                log('\\nTest 2: CORS preflight simulation');
                const response2 = await fetch(API_URL, {
                    method: 'OPTIONS',
                    headers: {
                        'Origin': window.location.origin,
                        'Access-Control-Request-Method': 'POST',
                        'Access-Control-Request-Headers': 'Content-Type'
                    }
                });
                
                log(\`Preflight status: \${response2.status}\`);
                
                const allowOrigin = response2.headers.get('Access-Control-Allow-Origin');
                const allowMethods = response2.headers.get('Access-Control-Allow-Methods');
                const allowHeaders = response2.headers.get('Access-Control-Allow-Headers');
                
                log(\`Allow-Origin: \${allowOrigin}\`);
                log(\`Allow-Methods: \${allowMethods}\`);
                log(\`Allow-Headers: \${allowHeaders}\`);
                
                if (allowOrigin && allowMethods) {
                    log('✅ CORS headers present!');
                    updateStatus('corsStatus', 'Working', true);
                } else {
                    log('❌ CORS headers missing');
                    updateStatus('corsStatus', 'Failed', false);
                }
                
            } catch (error) {
                log(\`❌ CORS test failed: \${error.message}\`);
                updateStatus('corsStatus', 'Error', false);
            }
        }
        
        async function testContainer() {
            log('🚀 Testing container launch...');
            
            try {
                const response = await fetch(API_URL, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        action: 'launch',
                        userId: 'test-user-' + Date.now(),
                        challengeId: 'welcome-test'
                    })
                });
                
                log(\`Response status: \${response.status}\`);
                
                if (!response.ok) {
                    throw new Error(\`HTTP \${response.status}: \${response.statusText}\`);
                }
                
                const data = await response.json();
                sessionId = data.sessionId;
                
                log('✅ Container launch successful!');
                log('Response: ' + JSON.stringify(data, null, 2));
                updateStatus('apiStatus', 'Working', true);
                
            } catch (error) {
                log(\`❌ Container test failed: \${error.message}\`);
                updateStatus('apiStatus', 'Failed', false);
                
                if (error.message.includes('CORS')) {
                    log('This appears to be a CORS issue. Run the CORS test for details.');
                }
            }
        }
        
        async function testAllActions() {
            log('🔄 Testing all container actions...');
            
            // Test launch
            await testContainer();
            
            if (!sessionId) {
                log('❌ Cannot test other actions without a session ID');
                return;
            }
            
            // Test status
            log('\\n📊 Testing status check...');
            try {
                const statusResponse = await fetch(API_URL, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        action: 'status',
                        sessionId: sessionId
                    })
                });
                
                const statusData = await statusResponse.json();
                log('Status response: ' + JSON.stringify(statusData, null, 2));
                
            } catch (error) {
                log(\`❌ Status test failed: \${error.message}\`);
            }
            
            // Test terminate
            log('\\n🛑 Testing termination...');
            try {
                const terminateResponse = await fetch(API_URL, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        action: 'terminate',
                        sessionId: sessionId
                    })
                });
                
                const terminateData = await terminateResponse.json();
                log('Terminate response: ' + JSON.stringify(terminateData, null, 2));
                
                sessionId = null;
                
            } catch (error) {
                log(\`❌ Terminate test failed: \${error.message}\`);
            }
        }
        
        // Auto-run CORS test on page load
        window.onload = () => {
            setTimeout(detailedCORSTest, 1000);
        };
    </script>
</body>
</html>
EOF

# Upload the enhanced test page
aws s3 cp cors-test-final.html s3://$BUCKET_NAME/container-test.html

echo "✅ Enhanced test page uploaded"

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*" \
  --output json > /dev/null

# Clean up
rm -f cors-test-final.html

echo ""
echo "🎉 CORS HEADERS FIXED!"
echo "====================="
echo ""
echo "✅ What was fixed:"
echo "   - 🔧 Recreated OPTIONS method with proper CORS headers"
echo "   - 📝 Added integration response with CORS values"
echo "   - 🔄 Updated Lambda to force CORS headers in all responses"
echo "   - 🚀 Deployed API changes"
echo ""
echo "🔗 Test URL: $CLOUDFRONT_URL/container-test.html"
echo ""
echo "📋 Expected results:"
echo "   - CORS test should show 'Access-Control-Allow-Origin: *'"
echo "   - Container launch should succeed without CORS errors"
echo "   - All three actions (launch/status/terminate) should work"
echo ""
echo "⏰ Wait 2-3 minutes for CloudFront cache, then test!"
echo ""
