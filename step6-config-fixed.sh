# Fixed DevOps Bootcamp Configuration
export BUCKET_NAME=devops-bootcamp-1749585074
export WEBSITE_URL=http://devops-bootcamp-1749585074.s3-website-us-east-1.amazonaws.com
export REGION=us-east-1
export DISTRIBUTION_ID=E3FB9TJY2P04OK
export CLOUDFRONT_DOMAIN=d1t1et5tjvep2.cloudfront.net
export CLOUDFRONT_URL=https://d1t1et5tjvep2.cloudfront.net

# NEW COGNITO CONFIGURATION
export USER_POOL_ID=us-east-1_1DiSyhXN5
export CLIENT_ID=365tghlhmtun70r5ltgimfav0i
export PUBLIC_CLIENT_ID=365tghlhmtun70r5ltgimfav0i
export COGNITO_DOMAIN=https://cognito-idp.us-east-1.amazonaws.com

# API CONFIGURATION  
export API_ID=hdxbz1zbx4
export API_ENDPOINT=https://hdxbz1zbx4.execute-api.us-east-1.amazonaws.com/prod
export DASHBOARD_URL=https://d1t1et5tjvep2.cloudfront.net/dashboard.html

# LAMBDA CONFIGURATION
export LAMBDA_FUNCTION_NAME=devops-bootcamp-api
export LAMBDA_ARN=arn:aws:lambda:us-east-1:677381153775:function:devops-bootcamp-api
export LAMBDA_ROLE_NAME=devops-bootcamp-lambda-role

# DYNAMODB CONFIGURATION
export USERS_TABLE=devops-bootcamp-users
export CHALLENGES_TABLE=devops-bootcamp-challenges
export PROGRESS_TABLE=devops-bootcamp-progress
export SESSIONS_TABLE=devops-bootcamp-sessions

# CONTAINER CONFIGURATION (if exists)
export ECR_REPO_URI=677381153775.dkr.ecr.us-east-1.amazonaws.com/devops-bootcamp/challenges
export CLUSTER_NAME=devops-bootcamp-challenges
export CONTAINER_LAMBDA_ARN=arn:aws:lambda:us-east-1:677381153775:function:devops-bootcamp-containers

# CONTAINER SYSTEM CONFIGURATION (FIXED)
export CONTAINER_LAMBDA_ARN=arn:aws:lambda:us-east-1:677381153775:function:devops-bootcamp-containers
export CONTAINERS_RESOURCE_ID=7ir2nu
export CONTAINER_ENDPOINTS="Fixed and Working"

