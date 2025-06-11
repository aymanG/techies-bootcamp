# 1. Health check should now show database connected
echo "1. Testing health endpoint:"
curl -s "$API_ENDPOINT/api/health" | jq .

# 2. Challenges should come from DynamoDB
echo -e "\n2. Testing challenges endpoint:"
curl -s "$API_ENDPOINT/api/challenges" | jq .

# 3. Get a token for authenticated tests
echo -e "\n3. To test authenticated endpoints:"
echo "   - Login at: $CLOUDFRONT_URL"
echo "   - Open Developer Tools (F12)"
echo "   - Run in console: localStorage.getItem('CognitoIdentityServiceProvider.${PUBLIC_CLIENT_ID}.LastAuthUser')"
