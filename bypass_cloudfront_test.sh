#!/bin/bash
# Test the API directly and create a test page that bypasses CloudFront cache issues

# Load configuration
source step6-config-fixed.sh 2>/dev/null || {
    echo "❌ Configuration not found"
    exit 1
}

echo "🔍 TESTING API DIRECTLY AND FIXING CACHE ISSUES"
echo "==============================================="

# Step 1: Test the API endpoint directly from command line
echo "📋 Step 1: Testing API Gateway directly..."

echo "Testing OPTIONS request:"
curl -v -X OPTIONS "$API_ENDPOINT/api/containers" \
  -H "Origin: https://example.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" \
  2>&1 | grep -E "(HTTP|access-control|Allow)"

echo -e "\nTesting POST request:"
DIRECT_POST=$(curl -s -X POST "$API_ENDPOINT/api/containers" \
  -H "Content-Type: application/json" \
  -H "Origin: https://example.com" \
  -d '{"action": "launch", "userId": "direct-test", "challengeId": "test"}')

echo "Direct POST result: $DIRECT_POST"

# Step 2: Check if there's a cache or integration issue
echo -e "\n📋 Step 2: Checking for integration issues..."

# Check the Lambda function logs
LOG_GROUP="/aws/lambda/devops-bootcamp-containers"
echo "Checking recent Lambda logs..."

LATEST_STREAM=$(aws logs describe-log-streams \
  --log-group-name $LOG_GROUP \
  --order-by LastEventTime \
  --descending \
  --limit 1 \
  --query 'logStreams[0].logStreamName' \
  --output text 2>/dev/null)

if [ "$LATEST_STREAM" != "None" ] && [ "$LATEST_STREAM" != "" ]; then
    echo "Recent Lambda logs:"
    aws logs get-log-events \
      --log-group-name $LOG_GROUP \
      --log-stream-name "$LATEST_STREAM" \
      --start-time $(echo "$(date +%s) - 300" | bc)000 \
      --query 'events[*].message' \
      --output text 2>/dev/null | tail -10
else
    echo "No recent Lambda logs found"
fi

# Step 3: Create a test page that tests the API directly (not through CloudFront)
echo -e "\n📋 Step 3: Creating direct API test page..."

cat > direct-api-test.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Direct API Test (No CloudFront)</title>
    <style>
        body { 
            background: #0a0a0a; 
            color: #00ff88; 
            font-family: monospace; 
            padding: 20px; 
            line-height: 1.6;
        }
        .container { max-width: 1000px; margin: 0 auto; }
        button { 
            background: #00ff88; 
            color: #0a0a0a; 
            border: none; 
            padding: 12px 24px; 
            margin: 8px; 
            cursor: pointer; 
            border-radius: 5px; 
            font-weight: bold;
            font-size: 14px;
        }
        button:hover { background: #00cc6f; }
        .response { 
            background: #1a1a1a; 
            padding: 20px; 
            margin: 15px 0; 
            border-radius: 8px; 
            border: 1px solid #333; 
            white-space: pre-wrap; 
            max-height: 500px;
            overflow-y: auto;
            font-size: 13px;
        }
        .status { padding: 15px; border-radius: 8px; margin: 15px 0; }
        .success { background: #1a3a1a; border: 2px solid #00ff88; }
        .error { background: #3a1a1a; border: 2px solid #ff0088; color: #ff0088; }
        .warning { background: #3a2a1a; border: 2px solid #ffaa00; color: #ffaa00; }
        .info { background: #1a2a3a; border: 2px solid #0088ff; color: #0088ff; }
        h1, h3 { color: #00ff88; text-shadow: 0 0 10px rgba(0,255,136,0.3); }
        .config { 
            background: #0a2a0a; 
            padding: 20px; 
            border-radius: 8px; 
            margin-bottom: 25px; 
            border: 1px solid #00ff88;
        }
        .endpoint-box {
            background: #0a0a0a;
            padding: 10px;
            border-radius: 5px;
            font-family: monospace;
            margin: 10px 0;
            border: 1px solid #333;
        }
        .grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin: 20px 0;
        }
        @media (max-width: 768px) {
            .grid { grid-template-columns: 1fr; }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎯 Direct API Test (Bypass CloudFront)</h1>
        
        <div class="config">
            <h3>Direct API Testing:</h3>
            <div class="endpoint-box">
                <strong>API Gateway Direct:</strong> $API_ENDPOINT/api/containers
            </div>
            <div class="endpoint-box">
                <strong>CloudFront URL:</strong> $CLOUDFRONT_URL (cached)
            </div>
            <p><strong>Test Strategy:</strong> Test API Gateway directly to bypass CloudFront caching issues</p>
            <p><strong>CORS Status:</strong> <span id="corsStatus">Not tested</span></p>
            <p><strong>API Status:</strong> <span id="apiStatus">Not tested</span></p>
        </div>
        
        <div class="status warning">
            <strong>⚠️ Important:</strong> This page tests the API Gateway directly to avoid CloudFront caching issues. 
            If this works but your main dashboard doesn't, it's a CloudFront configuration problem.
        </div>
        
        <div class="grid">
            <div>
                <h3>🔧 Diagnostic Tests:</h3>
                <button onclick="testDirectCORS()">🎯 Test Direct CORS</button>
                <button onclick="testThroughCloudFront()">☁️ Test via CloudFront</button>
                <button onclick="compareEndpoints()">🔄 Compare Both</button>
                <button onclick="clearLogs()">🧹 Clear</button>
            </div>
            <div>
                <h3>🚀 API Function Tests:</h3>
                <button onclick="testDirectAPI()">🎯 Direct API Test</button>
                <button onclick="testAllActions()">🔄 Test All Actions</button>
                <button onclick="loadMainDashboard()">📊 Test Dashboard</button>
                <button onclick="fixCloudFront()">🔧 Fix CloudFront</button>
            </div>
        </div>
        
        <div id="logs" class="response">Ready to test API directly...\n</div>
    </div>
    
    <script>
        // Direct API Gateway endpoint (bypasses CloudFront)
        const DIRECT_API = '$API_ENDPOINT/api/containers';
        const CLOUDFRONT_API = '$CLOUDFRONT_URL/api/containers';
        
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
            if (el) {
                el.textContent = status;
                el.style.color = success ? '#00ff88' : '#ff0088';
            }
        }
        
        async function testDirectCORS() {
            log('🎯 Testing CORS on direct API Gateway endpoint...');
            log('Endpoint: ' + DIRECT_API);
            
            try {
                // Test OPTIONS request directly to API Gateway
                const response = await fetch(DIRECT_API, {
                    method: 'OPTIONS',
                    headers: {
                        'Origin': window.location.origin,
                        'Access-Control-Request-Method': 'POST',
                        'Access-Control-Request-Headers': 'Content-Type'
                    }
                });
                
                log(\`Status: \${response.status}\`);
                
                const allowOrigin = response.headers.get('Access-Control-Allow-Origin');
                const allowMethods = response.headers.get('Access-Control-Allow-Methods');
                const allowHeaders = response.headers.get('Access-Control-Allow-Headers');
                
                log(\`Allow-Origin: \${allowOrigin}\`);
                log(\`Allow-Methods: \${allowMethods}\`);
                log(\`Allow-Headers: \${allowHeaders}\`);
                
                if (allowOrigin && allowMethods) {
                    log('✅ Direct API CORS is working!');
                    updateStatus('corsStatus', 'Direct API: Working', true);
                    return true;
                } else {
                    log('❌ Direct API CORS headers missing');
                    updateStatus('corsStatus', 'Direct API: Failed', false);
                    return false;
                }
                
            } catch (error) {
                log(\`❌ Direct CORS test failed: \${error.message}\`);
                updateStatus('corsStatus', 'Direct API: Error', false);
                return false;
            }
        }
        
        async function testThroughCloudFront() {
            log('☁️ Testing CORS through CloudFront...');
            log('Endpoint: ' + CLOUDFRONT_API);
            
            try {
                const response = await fetch(CLOUDFRONT_API, {
                    method: 'OPTIONS',
                    headers: {
                        'Origin': window.location.origin,
                        'Access-Control-Request-Method': 'POST',
                        'Access-Control-Request-Headers': 'Content-Type'
                    }
                });
                
                log(\`CloudFront status: \${response.status}\`);
                
                const allowOrigin = response.headers.get('Access-Control-Allow-Origin');
                const allowMethods = response.headers.get('Access-Control-Allow-Methods');
                
                log(\`CF Allow-Origin: \${allowOrigin}\`);
                log(\`CF Allow-Methods: \${allowMethods}\`);
                
                if (allowOrigin && allowMethods) {
                    log('✅ CloudFront CORS is working!');
                    return true;
                } else {
                    log('❌ CloudFront not passing CORS headers');
                    log('💡 This is why your dashboard fails - CloudFront cache issue');
                    return false;
                }
                
            } catch (error) {
                log(\`❌ CloudFront test failed: \${error.message}\`);
                return false;
            }
        }
        
        async function compareEndpoints() {
            log('🔄 Comparing Direct API vs CloudFront...');
            
            const directWorks = await testDirectCORS();
            await new Promise(resolve => setTimeout(resolve, 1000));
            const cloudFrontWorks = await testThroughCloudFront();
            
            log('\\n📊 COMPARISON RESULTS:');
            log(\`Direct API Gateway: \${directWorks ? '✅ Working' : '❌ Failed'}\`);
            log(\`Through CloudFront: \${cloudFrontWorks ? '✅ Working' : '❌ Failed'}\`);
            
            if (directWorks && !cloudFrontWorks) {
                log('\\n💡 DIAGNOSIS: CloudFront cache issue');
                log('SOLUTION: Clear CloudFront cache or update CloudFront config');
            } else if (!directWorks) {
                log('\\n💡 DIAGNOSIS: API Gateway CORS issue');
                log('SOLUTION: Fix API Gateway CORS configuration');
            }
        }
        
        async function testDirectAPI() {
            log('🎯 Testing container API directly...');
            
            try {
                const response = await fetch(DIRECT_API, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        action: 'launch',
                        userId: 'direct-test-' + Date.now(),
                        challengeId: 'direct-test'
                    })
                });
                
                log(\`Direct API status: \${response.status}\`);
                
                if (!response.ok) {
                    const errorText = await response.text();
                    log(\`Error response: \${errorText}\`);
                    throw new Error(\`HTTP \${response.status}: \${response.statusText}\`);
                }
                
                const data = await response.json();
                sessionId = data.sessionId;
                
                log('✅ Direct API call successful!');
                log('Response: ' + JSON.stringify(data, null, 2));
                updateStatus('apiStatus', 'Direct API: Working', true);
                
                return true;
                
            } catch (error) {
                log(\`❌ Direct API test failed: \${error.message}\`);
                updateStatus('apiStatus', 'Direct API: Failed', false);
                return false;
            }
        }
        
        async function testAllActions() {
            log('🔄 Testing all container actions on direct API...');
            
            // Test launch
            const launched = await testDirectAPI();
            if (!launched || !sessionId) {
                log('❌ Cannot test other actions without successful launch');
                return;
            }
            
            // Test status
            log('\\n📊 Testing status check...');
            try {
                const statusResponse = await fetch(DIRECT_API, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        action: 'status',
                        sessionId: sessionId
                    })
                });
                
                const statusData = await statusResponse.json();
                log('✅ Status check successful:');
                log(JSON.stringify(statusData, null, 2));
                
            } catch (error) {
                log(\`❌ Status check failed: \${error.message}\`);
            }
            
            // Test terminate
            log('\\n🛑 Testing termination...');
            try {
                const terminateResponse = await fetch(DIRECT_API, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        action: 'terminate',
                        sessionId: sessionId
                    })
                });
                
                const terminateData = await terminateResponse.json();
                log('✅ Termination successful:');
                log(JSON.stringify(terminateData, null, 2));
                
            } catch (error) {
                log(\`❌ Termination failed: \${error.message}\`);
            }
        }
        
        function loadMainDashboard() {
            log('📊 Opening main dashboard in new tab...');
            log('If the dashboard fails but this direct test works,');
            log('then CloudFront is the problem.');
            window.open('$CLOUDFRONT_URL/dashboard.html', '_blank');
        }
        
        async function fixCloudFront() {
            log('🔧 CloudFront fix instructions:');
            log('1. The API Gateway is working (if direct tests pass)');
            log('2. CloudFront is not passing CORS headers properly');
            log('3. Solutions:');
            log('   a) Clear CloudFront cache completely');
            log('   b) Update CloudFront to forward all headers');
            log('   c) Use direct API endpoint in dashboard temporarily');
            log('');
            log('Direct API endpoint to use: ' + DIRECT_API);
        }
        
        // Auto-run comparison test on page load
        window.onload = () => {
            setTimeout(compareEndpoints, 1000);
        };
    </script>
</body>
</html>
EOF

# Upload the direct test page
aws s3 cp direct-api-test.html s3://$BUCKET_NAME/direct-api-test.html

echo "✅ Direct API test page uploaded"

# Step 4: Clear CloudFront cache completely
echo -e "\n📋 Step 4: Clearing CloudFront cache completely..."

INVALIDATION_ID=$(aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*" \
  --query 'Invalidation.Id' \
  --output text)

echo "CloudFront invalidation started: $INVALIDATION_ID"

# Step 5: Check CloudFront distribution behavior settings
echo -e "\n📋 Step 5: Checking CloudFront distribution settings..."

DISTRIBUTION_CONFIG=$(aws cloudfront get-distribution-config --id $DISTRIBUTION_ID)
BEHAVIORS=$(echo $DISTRIBUTION_CONFIG | jq '.DistributionConfig.DefaultCacheBehavior')

echo "Current CloudFront cache behavior:"
echo $BEHAVIORS | jq '{
  ViewerProtocolPolicy: .ViewerProtocolPolicy,
  AllowedMethods: .AllowedMethods.Items,
  CachedMethods: .CachedMethods.Items,
  ForwardedHeaders: .ForwardedValues.Headers.Items,
  QueryString: .ForwardedValues.QueryString
}'

# Step 6: Update dashboard to use direct API temporarily
echo -e "\n📋 Step 6: Creating dashboard that uses direct API..."

# Download current dashboard
aws s3 cp s3://$BUCKET_NAME/dashboard.html temp-dashboard.html 2>/dev/null

if [ -f temp-dashboard.html ]; then
    # Replace CloudFront API URLs with direct API Gateway URLs
    sed -i "s|$CLOUDFRONT_URL/api/|$API_ENDPOINT/api/|g" temp-dashboard.html
    
    # Upload modified dashboard
    aws s3 cp temp-dashboard.html s3://$BUCKET_NAME/dashboard-direct.html
    
    echo "✅ Created dashboard with direct API: dashboard-direct.html"
    rm temp-dashboard.html
fi

echo ""
echo "🎯 DIRECT API TESTING SETUP COMPLETE"
echo "===================================="
echo ""
echo "📊 Test Results Summary:"
if echo "$DIRECT_POST" | grep -q "session-"; then
    echo "   ✅ Direct API Gateway: WORKING"
else
    echo "   ❌ Direct API Gateway: FAILED"
fi
echo ""
echo "🔗 Test URLs:"
echo "   📋 Direct API Test: $CLOUDFRONT_URL/direct-api-test.html"
echo "   📊 Dashboard (Direct): $CLOUDFRONT_URL/dashboard-direct.html"
echo "   📊 Dashboard (Original): $CLOUDFRONT_URL/dashboard.html"
echo ""
echo "📋 Diagnosis Strategy:"
echo "   1. Test direct API first (should work)"
echo "   2. Compare with CloudFront API (may fail)"
echo "   3. If direct works but CloudFront fails = cache issue"
echo "   4. If direct fails = API Gateway issue"
echo ""
echo "💡 Next Steps:"
echo "   1. Wait 2-3 minutes for cache invalidation"
echo "   2. Test direct-api-test.html page"
echo "   3. If direct API works, use dashboard-direct.html"
echo ""
