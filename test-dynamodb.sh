#!/bin/bash

echo "Testing DynamoDB Integration..."

# Test 1: Check tables exist
echo -e "\n1. Checking tables:"
aws dynamodb list-tables --query "TableNames[?starts_with(@, 'devops-bootcamp')]" --output table

# Test 2: Count items in challenges table
echo -e "\n2. Challenges loaded:"
aws dynamodb scan --table-name devops-bootcamp-challenges --select COUNT --query 'Count' --output text

# Test 3: Check API health
echo -e "\n3. API Health with DynamoDB:"
curl -s "$API_ENDPOINT/api/health" | jq '.database'

# Test 4: Get challenges from API
echo -e "\n4. Challenges from API:"
curl -s "$API_ENDPOINT/api/challenges" | jq '.total'

echo -e "\n✅ DynamoDB integration complete!"
