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
curl -s "$API_ENDPOINT/api/containers" -X POST -H "Content-Type: application/json" -d '{"action":"invalid"}' 2>/dev/null | grep -q error && echo "✓ Container API endpoint working" || echo "✗ Container API not responding"

echo -e "\n🎉 Container System Complete!"
