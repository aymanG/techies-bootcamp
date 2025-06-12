#!/bin/bash
# Quick diagnostic script to check current status

echo "🔍 QUICK DIAGNOSTIC CHECK"
echo "========================="

# Load config
for config_file in step6-config-fixed.sh step5-config.sh step4-config.sh; do
    if [ -f "$config_file" ]; then
        source "$config_file"
        echo "✅ Using config: $config_file"
        break
    fi
done

echo ""
echo "📋 Current Configuration:"
echo "API Endpoint: $API_ENDPOINT"
echo "CloudFront URL: $CLOUDFRONT_URL"

echo ""
echo "🎯 Testing Direct API CORS..."
DIRECT_CORS=$(curl -s -I -X OPTIONS "$API_ENDPOINT/api/containers" -H "Origin: https://example.com" | grep -i "access-control-allow-origin" | head -1)

if [ ! -z "$DIRECT_CORS" ]; then
    echo "✅ Direct API CORS: WORKING"
    echo "   $DIRECT_CORS"
else
    echo "❌ Direct API CORS: FAILED"
fi

echo ""
echo "☁️ Testing CloudFront CORS..."
CF_CORS=$(curl -s -I -X OPTIONS "$CLOUDFRONT_URL/api/containers" -H "Origin: https://example.com" | grep -i "access-control-allow-origin" | head -1)

if [ ! -z "$CF_CORS" ]; then
    echo "✅ CloudFront CORS: WORKING"
    echo "   $CF_CORS"
else
    echo "❌ CloudFront CORS: FAILED"
fi

echo ""
echo "🚀 Testing Container API..."
API_TEST=$(curl -s -X POST "$API_ENDPOINT/api/containers" \
    -H "Content-Type: application/json" \
    -d '{"action": "launch", "userId": "test", "challengeId": "welcome"}' | jq -r '.sessionId // "FAILED"')

if [ "$API_TEST" != "FAILED" ] && [ "$API_TEST" != "null" ]; then
    echo "✅ Container API: WORKING"
    echo "   Session ID: $API_TEST"
else
    echo "❌ Container API: FAILED"
fi

echo ""
echo "📊 SUMMARY:"
if [ ! -z "$DIRECT_CORS" ] && [ "$API_TEST" != "FAILED" ]; then
    echo "🎉 Your API is working! Dashboard should load now."
    echo ""
    echo "🔗 Test your dashboard: $CLOUDFRONT_URL/dashboard.html"
else
    echo "⚠️ Issues detected. Next steps:"
    echo "1. Run the complete CORS fix script"
    echo "2. Check AWS console for any error messages"
    echo "3. Verify API Gateway deployment status"
fi
