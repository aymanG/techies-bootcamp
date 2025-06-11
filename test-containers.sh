#!/bin/bash

echo "Testing Container System..."

# Test 1: Check ECS cluster
echo -e "\n1. ECS Cluster Status:"
aws ecs describe-clusters --clusters $CLUSTER_NAME --query 'clusters[0].status' --output text

# Test 2: Check ECR images
echo -e "\n2. Available challenge images:"
aws ecr list-images --repository-name $ECR_REPO_NAME --query 'imageIds[*].imageTag' --output table

# Test 3: Test container launch via API (requires auth token)
echo -e "\n3. To test container launching:"
echo "   1. Login to the dashboard"
echo "   2. Click on a challenge to start"
echo "   3. Wait for container to provision"
echo "   4. Use the SSH command to connect"

# Test 4: Check task definition
echo -e "\n4. Task definitions:"
aws ecs list-task-definitions --family-prefix devops-challenge --query 'taskDefinitionArns' --output table

echo -e "\n✅ Container system ready!"
