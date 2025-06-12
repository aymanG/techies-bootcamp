echo -e "\n=== Container System Validation ==="

# 1. ECS cluster exists
aws ecs describe-clusters --clusters $CLUSTER_NAME --query 'clusters[0].clusterName' --output text | grep -q $CLUSTER_NAME && echo "✓ ECS cluster created" || echo "✗ ECS cluster missing"

# 2. ECR repository exists
aws ecr describe-repositories --repository-names $ECR_REPO_NAME --query 'repositories[0].repositoryName' --output text 2>/dev/null | grep -q challenges && echo "✓ ECR repository created" || echo "✗ ECR repository missing"

# 3. Security group configured
aws ec2 describe-security-groups --group-ids $SECURITY_GROUP_ID --query 'SecurityGroups[0].GroupId' --output text | grep -q sg- && echo "✓ Security group configured" || echo "✗ Security group missing"

# 4. Container Lambda deployed
aws lambda get-function --function-name devops-bootcamp-containers --query 'Configuration.FunctionName' --output text 2>/dev/null | grep -q containers && echo "✓ Container Lambda deployed" || echo "✗ Container Lambda missing"

# 5. API endpoint exists
curl -s "$API_ENDPOINT/api/containers" -X POST -H "Authorization: eyJraWQiOiJ5Q1RlQWorcU9Bajg0QlFcL1FDRCtza3JvQ21GRWxFc0lLQzR0UCtROGVvTT0iLCJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJhNDQ4YzQwOC05MGQxLTcwYjMtNWI5NC1mM2FmODVkY2FiYWMiLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwiaXNzIjoiaHR0cHM6XC9cL2NvZ25pdG8taWRwLnVzLWVhc3QtMS5hbWF6b25hd3MuY29tXC91cy1lYXN0LTFfc2djUjBueXlqIiwiY29nbml0bzp1c2VybmFtZSI6ImE0NDhjNDA4LTkwZDEtNzBiMy01Yjk0LWYzYWY4NWRjYWJhYyIsIm9yaWdpbl9qdGkiOiJkMjcyNzQ3Yy02MTdkLTQxZTctYTc5MS1mOTI5Y2UzNTA5OTYiLCJhdWQiOiI2cWdsMWFmdW90cjZ1MXBhNG4ya2ZucmNtbCIsImV2ZW50X2lkIjoiZjIxZTZhZmItMTMxZS00MzFiLTgyMjItNDQ4NTcxNTIyYmM5IiwidG9rZW5fdXNlIjoiaWQiLCJhdXRoX3RpbWUiOjE3NDk2ODMxNDksImV4cCI6MTc0OTY4Njc0OSwiaWF0IjoxNzQ5NjgzMTQ5LCJqdGkiOiI3OWI0ZGZiNS1lY2NiLTRjNTYtOWM1YS01OGUxODk5YjEwZDUiLCJlbWFpbCI6IjAxMmVycm9yK2Rldm9wc0BnbWFpbC5jb20ifQ.bqABkN7rK5fJW21AUAMm2uSqXzOViEUvtFrO3AIuXocde0UCXjssDA2_ZWv0oKBZ68MEl3_9b0bDwhxV6ADS6iFGNoZms66a97Hi9HeHuBZNt_9JgC2UoUndyaZM-Em832PqWxNdGr7VKy2kptHndttVEANaiqp6UPwu0NcGVpFAVTfWXVFAruJFu1BURC26ZaJPt85-n3zJxCl5UxTNtlnr319o_D4EQiwhyF7FHNT9HUbt6EFUC4buWnR8l43MNZ-tezGljxDZwddT3n1OEvLa-PgLp2Cdk8tUyQVmsMDhSBd7RAgorSIdzGcd8ler-Uxcr8ZuBItgUNIm6B0JOg" -H "Content-Type: application/json" -d '{"action":"invalid"}' 2>/dev/null | grep -q error && echo "✓ Container API endpoint working" || echo "✗ Container API not responding"

echo -e "\n🎉 Container System Complete!"
