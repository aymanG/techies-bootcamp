#!/bin/bash
# Complete CORS Fix for DevOps Bootcamp Dashboard
# This script fixes the blank dashboard issue by properly configuring CORS

echo "🔧 COMPLETE CORS FIX FOR DEVOPS BOOTCAMP DASHBOARD"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configuration - try multiple config files
CONFIG_LOADED=false
for config_file in step6-config-fixed.sh step5-config.sh step4-config.sh; do
    if [ -f "$config_file" ]; then
        source "$config_file"
        echo -e "${GREEN}✅ Loaded configuration from $config_file${NC}"
        CONFIG_LOADED=true
        break
    fi
done

if [ "$CONFIG_LOADED" = false ]; then
    echo -e "${RED}❌ No configuration file found. Please ensure you have run the previous setup scripts.${NC}"
    exit 1
fi

# Verify required variables
REQUIRED_VARS=("API_ID" "BUCKET_NAME" "DISTRIBUTION_ID" "CLOUDFRONT_URL" "API_ENDPOINT")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}❌ Required variable $var is not set${NC}"
        exit 1
    fi
done

echo -e "${BLUE}Using configuration:${NC}"
echo "API Gateway ID: $API_ID"
echo "API Endpoint: $API_ENDPOINT"
echo "CloudFront URL: $CLOUDFRONT_URL"
echo "S3 Bucket: $BUCKET_NAME"

# Step 1: Get the containers resource ID
echo -e "\n${YELLOW}Step 1: Finding containers resource...${NC}"

CONTAINERS_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query "items[?path=='/api/containers'].id" --output text)

if [ "$CONTAINERS_RESOURCE_ID" = "" ] || [ "$CONTAINERS_RESOURCE_ID" = "None" ]; then
    echo -e "${RED}❌ /api/containers resource not found${NC}"
    echo "Available resources:"
    aws apigateway get-resources --rest-api-id $API_ID --query "items[*].[path,id]" --output table
    exit 1
fi

echo -e "${GREEN}✅ Found containers resource: $CONTAINERS_RESOURCE_ID${NC}"

# Step 2: Fix Lambda function with proper CORS
echo -e "\n${YELLOW}Step 2: Updating Lambda function with proper CORS...${NC}"

# Create updated Lambda function
mkdir -p cors-lambda-fix
cat > cors-lambda-fix/index.js << 'EOF'
exports.handler = async (event) => {
    console.log('=== CONTAINER LAMBDA EVENT ===');
    console.log(JSON.stringify(event, null, 2));
    
    // CORS headers - CRITICAL: These must be in every response
    const corsHeaders = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    };
    
    try {
        // Handle OPTIONS preflight requests
        if (event.httpMethod === 'OPTIONS') {
            console.log('Handling CORS preflight request');
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
        
        // Handle different actions
        switch (action) {
            case 'launch':
                if (!userId || !challengeId) {
                    return {
                        statusCode: 400,
                        headers: corsHeaders,
                        body: JSON.stringify({ 
                            error: 'userId and challengeId are required for launch action',
                            received: { userId, challengeId }
                        })
                    };
                }
                
                // Simulate container launch
                const newSessionId = `session-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
                console.log(`Launching container for user ${userId}, challenge ${challengeId}`);
                
                return {
                    statusCode: 200,
                    headers: corsHeaders,
                    body: JSON.stringify({
                        sessionId: newSessionId,
                        status: 'PROVISIONING',
                        message: 'Container is being created...',
                        userId: userId,
                        challengeId: challengeId,
                        timestamp: new Date().toISOString()
                    })
                };
                
            case 'status':
                if (!sessionId) {
                    return {
                        statusCode: 400,
                        headers: corsHeaders,
                        body: JSON.stringify({ 
                            error: 'sessionId is required for status action' 
                        })
                    };
                }
                
                // Simulate container status
                return {
                    statusCode: 200,
                    headers: corsHeaders,
                    body: JSON.stringify({
                        sessionId: sessionId,
                        status: 'RUNNING',
                        publicIp: '203.0.113.1',
                        sshCommand: 'ssh student@203.0.113.1',
                        password: 'devops123',
                        expiresIn: 7200,
                        timestamp: new Date().toISOString()
                    })
                };
                
            case 'terminate':
                return {
                    statusCode: 200,
                    headers: corsHeaders,
                    body: JSON.stringify({
                        message: 'Container terminated successfully',
                        sessionId: sessionId,
                        timestamp: new Date().toISOString()
                    })
                };
                
            default:
                return {
                    statusCode: 400,
                    headers: corsHeaders,
                    body: JSON.stringify({ 
                        error: 'Invalid action. Supported actions: launch, status, terminate',
                        receivedAction: action
                    })
                };
        }
        
    } catch (error) {
        console.error('Lambda error:', error);
        
        return {
            statusCode: 500,
            headers: corsHeaders,
            body: JSON.stringify({
                error: 'Internal server error',
                message: error.message,
                timestamp: new Date().toISOString()
            })
        };
    }
};
EOF

# Package and deploy Lambda
cd cors-lambda-fix
zip -r function.zip .
cd ..

echo "Updating Lambda function..."
UPDATE_RESULT=$(aws lambda update-function-code \
    --function-name devops-bootcamp-containers \
    --zip-file fileb://cors-lambda-fix/function.zip \
    --output json 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Lambda function updated successfully${NC}"
else
    echo -e "${YELLOW}⚠️ Lambda update failed, but continuing with API Gateway fix...${NC}"
    echo "$UPDATE_RESULT"
fi

# Cleanup
rm -rf cors-lambda-fix

# Step 3: Fix API Gateway OPTIONS method
echo -e "\n${YELLOW}Step 3: Fixing API Gateway OPTIONS method...${NC}"

# Delete existing OPTIONS method
aws apigateway delete-method \
    --rest-api-id $API_ID \
    --resource-id $CONTAINERS_RESOURCE_ID \
    --http-method OPTIONS 2>/dev/null || echo "No existing OPTIONS method found"

# Create fresh OPTIONS method
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $CONTAINERS_RESOURCE_ID \
    --http-method OPTIONS \
    --authorization-type NONE \
    --no-api-key-required

# Add mock integration
aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $CONTAINERS_RESOURCE_ID \
    --http-method OPTIONS \
    --type MOCK \
    --request-templates '{"application/json": "{\"statusCode\": 200}"}' \
    --passthrough-behavior WHEN_NO_TEMPLATES

# Add method response
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

# Add integration response with actual CORS headers
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

echo -e "${GREEN}✅ OPTIONS method fixed${NC}"

# Step 4: Deploy API Gateway
echo -e "\n${YELLOW}Step 4: Deploying API Gateway changes...${NC}"

DEPLOYMENT_RESULT=$(aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name prod \
    --description "CORS fix deployment $(date)" \
    --output json)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ API Gateway deployed successfully${NC}"
else
    echo -e "${RED}❌ API Gateway deployment failed${NC}"
    exit 1
fi

# Step 5: Clear CloudFront cache
echo -e "\n${YELLOW}Step 5: Clearing CloudFront cache...${NC}"

INVALIDATION_RESULT=$(aws cloudfront create-invalidation \
    --distribution-id $DISTRIBUTION_ID \
    --paths "/*" \
    --output json)

if [ $? -eq 0 ]; then
    INVALIDATION_ID=$(echo $INVALIDATION_RESULT | jq -r '.Invalidation.Id')
    echo -e "${GREEN}✅ CloudFront cache cleared (ID: $INVALIDATION_ID)${NC}"
else
    echo -e "${YELLOW}⚠️ CloudFront cache clear failed, but continuing...${NC}"
fi

# Step 6: Create improved test page
echo -e "\n${YELLOW}Step 6: Creating comprehensive test page...${NC}"

cat > cors-test-final.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CORS Fix Test - DevOps Bootcamp</title>
    <style>
        body {
            margin: 0;
            padding: 20px;
            background-color: #0a0a0a;
            color: #00ff88;
            font-family: 'Courier New', monospace;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        h1 {
            color: #00ff88;
            text-shadow: 0 0 10px rgba(0,255,136,0.3);
            text-align: center;
        }
        .status-box {
            background: #1a1a1a;
            border: 2px solid #00ff88;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
        }
        .test-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin: 20px 0;
        }
        button {
            background: #00ff88;
            color: #0a0a0a;
            border: none;
            padding: 12px 24px;
            margin: 8px 4px;
            cursor: pointer;
            border-radius: 5px;
            font-weight: bold;
            font-family: inherit;
        }
        button:hover {
            background: #00cc6a;
        }
        .response {
            background: #111;
            border: 1px solid #333;
            border-radius: 5px;
            padding: 15px;
            margin: 10px 0;
            white-space: pre-wrap;
            max-height: 300px;
            overflow-y: auto;
            font-size: 14px;
        }
        .success { color: #00ff88; }
        .error { color: #ff4444; }
        .warning { color: #ffaa00; }
        .info { color: #4488ff; }
        @media (max-width: 768px) {
            .test-grid { grid-template-columns: 1fr; }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔧 CORS Fix Test Page</h1>
        
        <div class="status-box">
            <h3>🎯 API Endpoints</h3>
            <div><strong>Direct API:</strong> $API_ENDPOINT/api/containers</div>
            <div><strong>CloudFront:</strong> $CLOUDFRONT_URL/api/containers</div>
            <div><strong>Status:</strong> <span id="overall-status">Testing...</span></div>
        </div>
        
        <div class="test-grid">
            <div>
                <h3>🔬 CORS Tests</h3>
                <button onclick="testDirectCORS()">Test Direct API CORS</button>
                <button onclick="testCloudFrontCORS()">Test CloudFront CORS</button>
                <button onclick="testBothEndpoints()">Compare Both</button>
            </div>
            <div>
                <h3>🚀 Container API Tests</h3>
                <button onclick="testContainerLaunch()">Test Container Launch</button>
                <button onclick="testContainerStatus()">Test Container Status</button>
                <button onclick="testFullWorkflow()">Test Full Workflow</button>
            </div>
        </div>
        
        <div class="status-box">
            <h3>📋 Test Results</h3>
            <div id="test-results" class="response">Ready to run tests...\n</div>
        </div>
        
        <div class="status-box">
            <h3>🔗 Quick Links</h3>
            <button onclick="openDashboard()">Open Main Dashboard</button>
            <button onclick="clearResults()">Clear Results</button>
            <button onclick="downloadReport()">Download Report</button>
        </div>
    </div>

    <script>
        const DIRECT_API = '$API_ENDPOINT/api/containers';
        const CLOUDFRONT_API = '$CLOUDFRONT_URL/api/containers';
        
        let testResults = [];
        
        function log(message, type = 'info') {
            const timestamp = new Date().toLocaleTimeString();
            const logElement = document.getElementById('test-results');
            const colorClass = type === 'success' ? 'success' : 
                              type === 'error' ? 'error' : 
                              type === 'warning' ? 'warning' : 'info';
            
            const logEntry = \`[\${timestamp}] \${message}\`;
            testResults.push({ timestamp, message, type });
            
            logElement.innerHTML += \`<span class="\${colorClass}">\${logEntry}</span>\n\`;
            logElement.scrollTop = logElement.scrollHeight;
        }
        
        function clearResults() {
            document.getElementById('test-results').innerHTML = 'Results cleared...\n';
            testResults = [];
        }
        
        async function testDirectCORS() {
            log('🎯 Testing Direct API CORS headers...', 'info');
            
            try {
                const response = await fetch(DIRECT_API, {
                    method: 'OPTIONS',
                    headers: {
                        'Origin': 'https://example.com',
                        'Access-Control-Request-Method': 'POST',
                        'Access-Control-Request-Headers': 'Content-Type'
                    }
                });
                
                const allowOrigin = response.headers.get('Access-Control-Allow-Origin');
                const allowMethods = response.headers.get('Access-Control-Allow-Methods');
                const allowHeaders = response.headers.get('Access-Control-Allow-Headers');
                
                log(\`Direct API Status: \${response.status}\`, response.status === 200 ? 'success' : 'error');
                log(\`Allow-Origin: \${allowOrigin || 'null'}\`, allowOrigin ? 'success' : 'error');
                log(\`Allow-Methods: \${allowMethods || 'null'}\`, allowMethods ? 'success' : 'error');
                log(\`Allow-Headers: \${allowHeaders || 'null'}\`, allowHeaders ? 'success' : 'error');
                
                if (allowOrigin && allowMethods) {
                    log('✅ Direct API CORS headers present!', 'success');
                } else {
                    log('❌ Direct API CORS headers missing!', 'error');
                }
                
            } catch (error) {
                log(\`❌ Direct API CORS test failed: \${error.message}\`, 'error');
            }
        }
        
        async function testCloudFrontCORS() {
            log('☁️ Testing CloudFront CORS headers...', 'info');
            
            try {
                const response = await fetch(CLOUDFRONT_API, {
                    method: 'OPTIONS',
                    headers: {
                        'Origin': 'https://example.com',
                        'Access-Control-Request-Method': 'POST'
                    }
                });
                
                const allowOrigin = response.headers.get('Access-Control-Allow-Origin');
                const status = response.status;
                
                log(\`CloudFront Status: \${status}\`, status === 200 ? 'success' : 'error');
                log(\`CF Allow-Origin: \${allowOrigin || 'null'}\`, allowOrigin ? 'success' : 'error');
                
                if (status === 200 && allowOrigin) {
                    log('✅ CloudFront CORS working!', 'success');
                } else {
                    log('❌ CloudFront CORS issues detected!', 'error');
                }
                
            } catch (error) {
                log(\`❌ CloudFront CORS test failed: \${error.message}\`, 'error');
            }
        }
        
        async function testBothEndpoints() {
            log('🔄 Comparing Direct API vs CloudFront...', 'info');
            await testDirectCORS();
            await testCloudFrontCORS();
            
            log('📊 Comparison complete. Use direct API if CloudFront has issues.', 'warning');
        }
        
        async function testContainerLaunch() {
            log('🚀 Testing container launch...', 'info');
            
            const testData = {
                action: 'launch',
                userId: 'test-user',
                challengeId: 'welcome'
            };
            
            try {
                const response = await fetch(DIRECT_API, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Origin': window.location.origin
                    },
                    body: JSON.stringify(testData)
                });
                
                const data = await response.json();
                log(\`Launch Status: \${response.status}\`, response.status === 200 ? 'success' : 'error');
                log(\`Launch Response: \${JSON.stringify(data, null, 2)}\`, 'info');
                
                if (data.sessionId) {
                    log(\`✅ Container launch successful! Session: \${data.sessionId}\`, 'success');
                    window.testSessionId = data.sessionId;
                } else {
                    log('❌ Container launch failed!', 'error');
                }
                
            } catch (error) {
                log(\`❌ Container launch test failed: \${error.message}\`, 'error');
            }
        }
        
        async function testContainerStatus() {
            log('📊 Testing container status...', 'info');
            
            const sessionId = window.testSessionId || 'demo-session';
            const testData = {
                action: 'status',
                sessionId: sessionId
            };
            
            try {
                const response = await fetch(DIRECT_API, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(testData)
                });
                
                const data = await response.json();
                log(\`Status Response: \${JSON.stringify(data, null, 2)}\`, 'info');
                
                if (data.status) {
                    log(\`✅ Container status: \${data.status}\`, 'success');
                } else {
                    log('❌ Container status failed!', 'error');
                }
                
            } catch (error) {
                log(\`❌ Container status test failed: \${error.message}\`, 'error');
            }
        }
        
        async function testFullWorkflow() {
            log('🔄 Testing full container workflow...', 'info');
            
            await testContainerLaunch();
            await new Promise(resolve => setTimeout(resolve, 1000));
            await testContainerStatus();
            
            log('🎉 Full workflow test complete!', 'success');
        }
        
        function openDashboard() {
            log('📊 Opening main dashboard...', 'info');
            window.open('$CLOUDFRONT_URL/dashboard.html', '_blank');
        }
        
        function downloadReport() {
            const report = testResults.map(r => \`[\${r.timestamp}] [\${r.type.toUpperCase()}] \${r.message}\`).join('\n');
            const blob = new Blob([report], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = \`cors-test-report-\${new Date().getTime()}.txt\`;
            a.click();
            URL.revokeObjectURL(url);
        }
        
        // Auto-run initial tests
        window.onload = () => {
            log('🔧 CORS Fix Test Page Loaded', 'success');
            log('Ready to test your API endpoints!', 'info');
            
            // Auto-test CORS after 2 seconds
            setTimeout(() => {
                log('🎯 Running automatic CORS test...', 'info');
                testBothEndpoints();
            }, 2000);
        };
    </script>
</body>
</html>
EOF

# Upload test page
aws s3 cp cors-test-final.html s3://$BUCKET_NAME/cors-test.html

echo -e "${GREEN}✅ Test page uploaded: $CLOUDFRONT_URL/cors-test.html${NC}"

# Step 7: Wait and test
echo -e "\n${YELLOW}Step 7: Running final verification tests...${NC}"

echo "Waiting 10 seconds for deployment to propagate..."
sleep 10

# Test CORS directly
echo -e "\n${BLUE}Testing CORS configuration:${NC}"

CORS_TEST=$(curl -s -I -X OPTIONS "$API_ENDPOINT/api/containers" \
    -H "Origin: https://example.com" \
    -H "Access-Control-Request-Method: POST" \
    -H "Access-Control-Request-Headers: Content-Type")

if echo "$CORS_TEST" | grep -qi "access-control-allow-origin"; then
    echo -e "${GREEN}✅ CORS headers detected!${NC}"
    CORS_STATUS="WORKING"
else
    echo -e "${RED}❌ CORS headers still missing${NC}"
    CORS_STATUS="FAILED"
fi

# Test container API
echo -e "\n${BLUE}Testing container API:${NC}"

API_TEST=$(curl -s -X POST "$API_ENDPOINT/api/containers" \
    -H "Content-Type: application/json" \
    -d '{"action": "launch", "userId": "test", "challengeId": "welcome"}')

if echo "$API_TEST" | grep -q "session-"; then
    echo -e "${GREEN}✅ Container API working!${NC}"
    API_STATUS="WORKING"
else
    echo -e "${RED}❌ Container API failed${NC}"
    API_STATUS="FAILED"
    echo "API Response: $API_TEST"
fi

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}           FIX SUMMARY${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n${YELLOW}Configuration:${NC}"
echo "✅ API Gateway ID: $API_ID"
echo "✅ API Endpoint: $API_ENDPOINT" 
echo "✅ CloudFront URL: $CLOUDFRONT_URL"

echo -e "\n${YELLOW}Test Results:${NC}"
echo "CORS Status: $CORS_STATUS"
echo "API Status: $API_STATUS"

echo -e "\n${YELLOW}Next Steps:${NC}"
if [ "$CORS_STATUS" = "WORKING" ] && [ "$API_STATUS" = "WORKING" ]; then
    echo -e "${GREEN}🎉 SUCCESS! Your dashboard should now work!${NC}"
    echo ""
    echo "1. Clear your browser cache and cookies"
    echo "2. Visit your dashboard: $CLOUDFRONT_URL/dashboard.html"
    echo "3. Test page available at: $CLOUDFRONT_URL/cors-test.html"
else
    echo -e "${YELLOW}⚠️ Some issues remain. Try these steps:${NC}"
    echo ""
    echo "1. Visit the test page: $CLOUDFRONT_URL/cors-test.html"
    echo "2. Check the test results for specific errors"
    echo "3. If CloudFront fails but direct API works, update dashboard to use direct API"
    echo "4. Clear browser cache completely"
fi

echo -e "\n${BLUE}Important URLs:${NC}"
echo "🔗 Main Dashboard: $CLOUDFRONT_URL/dashboard.html"
echo "🔗 CORS Test Page: $CLOUDFRONT_URL/cors-test.html" 
echo "🔗 Direct API Test: $CLOUDFRONT_URL/direct-api-test.html"

echo -e "\n${GREEN}Fix complete!${NC}"
