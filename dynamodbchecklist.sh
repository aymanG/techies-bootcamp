echo -e "\n=== DynamoDB Implementation Validation ==="

# 1. All tables created
aws dynamodb list-tables --query "TableNames[?starts_with(@, 'devops-bootcamp')]" --output text | wc -w | grep -q 4 && echo "✓ All 4 tables created" || echo "✗ Missing tables"

# 2. Indexes configured
aws dynamodb describe-table --table-name $USERS_TABLE --query 'Table.GlobalSecondaryIndexes[*].IndexName' --output text | grep -q "email-index" && echo "✓ Email index created" || echo "✗ Email index missing"

# 3. TTL enabled
aws dynamodb describe-time-to-live --table-name $SESSIONS_TABLE --query 'TimeToLiveDescription.TimeToLiveStatus' --output text | grep -q "ENABLED" && echo "✓ TTL enabled for sessions" || echo "✗ TTL not enabled"

# 4. Lambda has permissions
aws lambda get-function-configuration --function-name $LAMBDA_FUNCTION_NAME --query 'Environment.Variables.USERS_TABLE' --output text | grep -q $USERS_TABLE && echo "✓ Lambda configured with DynamoDB" || echo "✗ Lambda not configured"

# 5. API returns DynamoDB data
curl -s "$API_ENDPOINT/api/challenges" 2>/dev/null | jq -e '.challenges | length > 0' >/dev/null && echo "✓ API returns challenges from DynamoDB" || echo "✗ API not returning DynamoDB data"

echo -e "\n🎉 DynamoDB Integration Complete!"
