#!/bin/bash
# Monitor DynamoDB usage and performance

echo "=== DynamoDB Monitoring ==="
echo ""

# Check table metrics
for TABLE in devops-bootcamp-users devops-bootcamp-challenges devops-bootcamp-progress devops-bootcamp-sessions; do
    echo "Table: $TABLE"
    
    # Get item count
    ITEM_COUNT=$(aws dynamodb describe-table --table-name $TABLE --query 'Table.ItemCount' --output text)
    echo "  Items: $ITEM_COUNT"
    
    # Get table size
    TABLE_SIZE=$(aws dynamodb describe-table --table-name $TABLE --query 'Table.TableSizeBytes' --output text)
    echo "  Size: $(echo "scale=2; $TABLE_SIZE / 1024 / 1024" | bc) MB"
    
    # Get consumed capacity
    echo ""
done

# Check for hot partitions
echo "Checking for throttled requests..."
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name UserErrors \
  --dimensions Name=TableName,Value=devops-bootcamp-users \
  --statistics Sum \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --query 'Datapoints[0].Sum' \
  --output text
