# Phase 2 - Step 7: Container Launching System with ECS Fargate

## Goal
Implement a robust container launching system using ECS Fargate that provides isolated Linux environments for each challenge

## Prerequisites
- Step 6 completed (DynamoDB working)
- `step6-config.sh` file with your configuration

## Step 7.1: Setup ECS Infrastructure

```bash
# Load previous configuration
source step6-config.sh
echo "Using Lambda: $LAMBDA_FUNCTION_NAME"

# Set ECS variables
export CLUSTER_NAME="devops-bootcamp-cluster"
export TASK_FAMILY="devops-bootcamp-challenges"
export ECR_REPO_NAME="devops-bootcamp/challenges"
```

## Step 7.2: Create ECR Repository for Challenge Images

```bash
# Create ECR repository
echo "Creating ECR repository for challenge images..."

ECR_REPO_OUTPUT=$(aws ecr create-repository \
  --repository-name $ECR_REPO_NAME \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  --tags Key=Project,Value=DevOpsBootcamp \
  --output json)

ECR_REPO_URI=$(echo $ECR_REPO_OUTPUT | jq -r '.repository.repositoryUri')
echo "ECR Repository URI: $ECR_REPO_URI"

# Get login token for Docker
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REPO_URI

# Save to config
echo "export ECR_REPO_URI=$ECR_REPO_URI" >> step6-config.sh
```

## Step 7.3: Create Base Challenge Docker Images

```bash
# Create directory for challenge images
mkdir -p challenges/docker-images/base

# Create base Dockerfile
cat > challenges/docker-images/base/Dockerfile << 'EOF'
FROM amazonlinux:2023

# Install essential packages
RUN yum update -y && \
    yum install -y \
    openssh-server \
    openssh-clients \
    sudo \
    vim \
    nano \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    nodejs \
    npm \
    bash-completion \
    tree \
    htop \
    nc \
    telnet \
    tar \
    gzip \
    unzip \
    which \
    passwd \
    shadow-utils \
    util-linux-user \
    && yum clean all

# Configure SSH
RUN ssh-keygen -A && \
    sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# Create student user
RUN useradd -m -s /bin/bash student && \
    echo "student:devops123" | chpasswd && \
    usermod -aG wheel student && \
    echo '%wheel ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Create validation framework
RUN mkdir -p /opt/validation /opt/challenges /var/log/challenges

# Add validation wrapper script
COPY validation-wrapper.sh /opt/validation/wrapper.sh
RUN chmod +x /opt/validation/wrapper.sh

# Add welcome message
RUN echo '#!/bin/bash' > /etc/profile.d/welcome.sh && \
    echo 'if [ "$USER" = "student" ]; then' >> /etc/profile.d/welcome.sh && \
    echo '  echo "================================================"' >> /etc/profile.d/welcome.sh && \
    echo '  echo "Welcome to DevOps Bootcamp!"' >> /etc/profile.d/welcome.sh && \
    echo '  echo "Challenge: $CHALLENGE_NAME"' >> /etc/profile.d/welcome.sh && \
    echo '  echo "================================================"' >> /etc/profile.d/welcome.sh && \
    echo '  echo ""' >> /etc/profile.d/welcome.sh && \
    echo '  if [ -f /opt/challenges/instructions.txt ]; then' >> /etc/profile.d/welcome.sh && \
    echo '    cat /opt/challenges/instructions.txt' >> /etc/profile.d/welcome.sh && \
    echo '  fi' >> /etc/profile.d/welcome.sh && \
    echo 'fi' >> /etc/profile.d/welcome.sh && \
    chmod +x /etc/profile.d/welcome.sh

# Set up environment
ENV CHALLENGE_NAME="Base Challenge"
ENV CHALLENGE_ID="base"

# Expose SSH port
EXPOSE 22

# Start SSH service
CMD ["/usr/sbin/sshd", "-D"]
EOF

# Create validation wrapper
cat > challenges/docker-images/base/validation-wrapper.sh << 'EOF'
#!/bin/bash
# Validation wrapper for challenges

VALIDATION_SCRIPT="/opt/validation/validate.sh"
CHALLENGE_ID="${CHALLENGE_ID:-unknown}"
USER_ID="${USER_ID:-unknown}"
SESSION_ID="${SESSION_ID:-unknown}"

# Log validation attempt
echo "[$(date)] Validation attempt for challenge $CHALLENGE_ID by user $USER_ID" >> /var/log/challenges/validation.log

# Run the actual validation script
if [ -f "$VALIDATION_SCRIPT" ]; then
    bash "$VALIDATION_SCRIPT"
    RESULT=$?
    
    # Log result
    echo "[$(date)] Validation result: $RESULT" >> /var/log/challenges/validation.log
    
    # If successful, create completion marker
    if [ $RESULT -eq 0 ]; then
        echo "SUCCESS:$(date):$USER_ID:$SESSION_ID" > /tmp/challenge_completed
    fi
    
    exit $RESULT
else
    echo "ERROR: Validation script not found"
    exit 1
fi
EOF

# Build base image
cd challenges/docker-images/base
docker build -t devops-bootcamp-base:latest .
docker tag devops-bootcamp-base:latest $ECR_REPO_URI:base
docker push $ECR_REPO_URI:base
cd ../../..
```

## Step 7.4: Create Specific Challenge Images

```bash
# Create Welcome Challenge
mkdir -p challenges/docker-images/welcome

cat > challenges/docker-images/welcome/Dockerfile << 'EOF'
FROM devops-bootcamp-base:latest

# Set challenge info
ENV CHALLENGE_NAME="Welcome to DevOps Academy"
ENV CHALLENGE_ID="welcome-01"

# Create challenge files
RUN mkdir -p /home/student/challenge && \
    echo "Welcome to your first DevOps challenge!" > /home/student/challenge/README.txt && \
    echo "" >> /home/student/challenge/README.txt && \
    echo "Your mission:" >> /home/student/challenge/README.txt && \
    echo "1. Find the hidden flag file somewhere in your home directory" >> /home/student/challenge/README.txt && \
    echo "2. Read the contents of the flag file" >> /home/student/challenge/README.txt && \
    echo "3. Run the validation command when you're ready" >> /home/student/challenge/README.txt && \
    echo "" >> /home/student/challenge/README.txt && \
    echo "Hints:" >> /home/student/challenge/README.txt && \
    echo "- Use 'ls -la' to see hidden files" >> /home/student/challenge/README.txt && \
    echo "- Hidden files start with a dot (.)" >> /home/student/challenge/README.txt && \
    echo "- The 'find' command can help locate files" >> /home/student/challenge/README.txt && \
    chown -R student:student /home/student/challenge

# Create the hidden flag
RUN echo "FLAG{WELCOME_TO_DEVOPS_ACADEMY_2024}" > /home/student/.secret_flag && \
    chmod 644 /home/student/.secret_flag && \
    chown student:student /home/student/.secret_flag

# Create validation script
RUN echo '#!/bin/bash' > /opt/validation/validate.sh && \
    echo 'FLAG_FILE="/home/student/.secret_flag"' >> /opt/validation/validate.sh && \
    echo 'FOUND_FILE="/home/student/.found_flag"' >> /opt/validation/validate.sh && \
    echo '' >> /opt/validation/validate.sh && \
    echo 'if [ -f "$FOUND_FILE" ]; then' >> /opt/validation/validate.sh && \
    echo '    echo "✅ Congratulations! You completed the challenge!"' >> /opt/validation/validate.sh && \
    echo '    exit 0' >> /opt/validation/validate.sh && \
    echo 'fi' >> /opt/validation/validate.sh && \
    echo '' >> /opt/validation/validate.sh && \
    echo 'if grep -q "FLAG{WELCOME_TO_DEVOPS_ACADEMY_2024}" ~/.bash_history 2>/dev/null; then' >> /opt/validation/validate.sh && \
    echo '    touch "$FOUND_FILE"' >> /opt/validation/validate.sh && \
    echo '    echo "✅ Congratulations! You found and read the flag!"' >> /opt/validation/validate.sh && \
    echo '    exit 0' >> /opt/validation/validate.sh && \
    echo 'fi' >> /opt/validation/validate.sh && \
    echo '' >> /opt/validation/validate.sh && \
    echo 'echo "❌ Challenge not completed yet. Keep looking for the hidden flag!"' >> /opt/validation/validate.sh && \
    echo 'exit 1' >> /opt/validation/validate.sh && \
    chmod +x /opt/validation/validate.sh

# Add instructions
COPY instructions.txt /opt/challenges/instructions.txt
EOF

# Create instructions file
cat > challenges/docker-images/welcome/instructions.txt << 'EOF'
🎯 Welcome Challenge Instructions
================================

Welcome to the DevOps Bootcamp! This is your first challenge to get familiar
with the Linux command line and the challenge system.

📋 Your Mission:
1. Find a hidden flag file in your home directory
2. Read the contents of the flag file
3. Validate your completion

💡 Useful Commands:
- ls -la        : List all files including hidden ones
- cd           : Change directory
- cat          : Display file contents
- pwd          : Show current directory
- find         : Search for files

🏁 To Check Your Progress:
Run: sudo /opt/validation/wrapper.sh

Good luck, future DevOps engineer!
EOF

# Build and push welcome challenge
cd challenges/docker-images/welcome
docker build -t devops-bootcamp-welcome:latest .
docker tag devops-bootcamp-welcome:latest $ECR_REPO_URI:welcome-01
docker push $ECR_REPO_URI:welcome-01
cd ../../..
```

## Step 7.5: Create ECS Cluster and Task Definition

```bash
# Create ECS cluster
echo "Creating ECS cluster..."
aws ecs create-cluster \
  --cluster-name $CLUSTER_NAME \
  --capacity-providers FARGATE FARGATE_SPOT \
  --default-capacity-provider-strategy \
    capacityProvider=FARGATE_SPOT,weight=80 \
    capacityProvider=FARGATE,weight=20 \
  --tags key=Project,value=DevOpsBootcamp \
  --output json > /dev/null

echo "ECS cluster created"

# Create task execution role
cat > ecs-task-execution-role-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the role
TASK_ROLE_OUTPUT=$(aws iam create-role \
  --role-name devops-bootcamp-task-execution-role \
  --assume-role-policy-document file://ecs-task-execution-role-policy.json \
  --output json 2>/dev/null || echo '{"Role": {"Arn": "existing"}}')

if [[ "$TASK_ROLE_OUTPUT" == *"existing"* ]]; then
    TASK_EXECUTION_ROLE_ARN=$(aws iam get-role --role-name devops-bootcamp-task-execution-role --query 'Role.Arn' --output text)
else
    TASK_EXECUTION_ROLE_ARN=$(echo $TASK_ROLE_OUTPUT | jq -r '.Role.Arn')
fi

# Attach policies
aws iam attach-role-policy \
  --role-name devops-bootcamp-task-execution-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

echo "Task execution role created"
```

## Step 7.6: Create Container Management Lambda

```bash
# Create new Lambda for container management
mkdir -p container-lambda

cat > container-lambda/index.js << 'EOF'
const AWS = require('aws-sdk');
const ecs = new AWS.ECS();
const ec2 = new AWS.EC2();
const dynamodb = new AWS.DynamoDB.DocumentClient();

const CLUSTER_NAME = process.env.CLUSTER_NAME;
const SUBNET_IDS = process.env.SUBNET_IDS ? process.env.SUBNET_IDS.split(',') : [];
const SECURITY_GROUP_ID = process.env.SECURITY_GROUP_ID;
const TASK_EXECUTION_ROLE_ARN = process.env.TASK_EXECUTION_ROLE_ARN;
const ECR_REPO_URI = process.env.ECR_REPO_URI;
const SESSIONS_TABLE = process.env.SESSIONS_TABLE;

exports.handler = async (event) => {
    console.log('Container Lambda Event:', JSON.stringify(event, null, 2));
    
    const { action, userId, challengeId, sessionId } = JSON.parse(event.body || '{}');
    
    try {
        switch (action) {
            case 'launch':
                return await launchContainer(userId, challengeId);
            case 'status':
                return await getContainerStatus(sessionId);
            case 'terminate':
                return await terminateContainer(sessionId);
            default:
                return {
                    statusCode: 400,
                    body: JSON.stringify({ error: 'Invalid action' })
                };
        }
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: error.message })
        };
    }
};

async function launchContainer(userId, challengeId) {
    // Check if user already has an active container
    const existingSession = await checkExistingSession(userId);
    if (existingSession) {
        return {
            statusCode: 400,
            body: JSON.stringify({ 
                error: 'Active session exists',
                sessionId: existingSession.sessionId 
            })
        };
    }
    
    // Generate session ID
    const sessionId = `session-${userId}-${Date.now()}`;
    const containerName = `challenge-${challengeId}-${sessionId}`;
    
    // Create task definition
    const taskDefinition = {
        family: `devops-challenge-${challengeId}`,
        networkMode: 'awsvpc',
        requiresCompatibilities: ['FARGATE'],
        cpu: '256',
        memory: '512',
        executionRoleArn: TASK_EXECUTION_ROLE_ARN,
        containerDefinitions: [{
            name: 'challenge',
            image: `${ECR_REPO_URI}:${challengeId}`,
            essential: true,
            portMappings: [{
                containerPort: 22,
                protocol: 'tcp'
            }],
            environment: [
                { name: 'USER_ID', value: userId },
                { name: 'CHALLENGE_ID', value: challengeId },
                { name: 'SESSION_ID', value: sessionId }
            ],
            logConfiguration: {
                logDriver: 'awslogs',
                options: {
                    'awslogs-group': '/ecs/devops-bootcamp',
                    'awslogs-region': process.env.AWS_REGION,
                    'awslogs-stream-prefix': 'challenge'
                }
            }
        }]
    };
    
    // Register task definition
    const registerResult = await ecs.registerTaskDefinition(taskDefinition).promise();
    const taskDefArn = registerResult.taskDefinition.taskDefinitionArn;
    
    // Run task
    const runTaskResult = await ecs.runTask({
        cluster: CLUSTER_NAME,
        taskDefinition: taskDefArn,
        launchType: 'FARGATE',
        networkConfiguration: {
            awsvpcConfiguration: {
                subnets: SUBNET_IDS,
                securityGroups: [SECURITY_GROUP_ID],
                assignPublicIp: 'ENABLED'
            }
        },
        overrides: {
            containerOverrides: [{
                name: 'challenge',
                environment: [
                    { name: 'CONTAINER_NAME', value: containerName }
                ]
            }]
        }
    }).promise();
    
    const task = runTaskResult.tasks[0];
    const taskArn = task.taskArn;
    
    // Save session to DynamoDB
    const expiresAt = Math.floor(Date.now() / 1000) + 7200; // 2 hours
    await dynamodb.put({
        TableName: SESSIONS_TABLE,
        Item: {
            sessionId,
            userId,
            challengeId,
            taskArn,
            status: 'PROVISIONING',
            createdAt: new Date().toISOString(),
            expiresAt,
            containerName
        }
    }).promise();
    
    return {
        statusCode: 200,
        body: JSON.stringify({
            sessionId,
            taskArn,
            status: 'PROVISIONING',
            message: 'Container is being provisioned. Check status in 30-60 seconds.'
        })
    };
}

async function getContainerStatus(sessionId) {
    // Get session from DynamoDB
    const result = await dynamodb.get({
        TableName: SESSIONS_TABLE,
        Key: { sessionId }
    }).promise();
    
    if (!result.Item) {
        return {
            statusCode: 404,
            body: JSON.stringify({ error: 'Session not found' })
        };
    }
    
    const session = result.Item;
    
    // Get task details
    const tasksResult = await ecs.describeTasks({
        cluster: CLUSTER_NAME,
        tasks: [session.taskArn]
    }).promise();
    
    if (tasksResult.tasks.length === 0) {
        return {
            statusCode: 200,
            body: JSON.stringify({
                sessionId,
                status: 'TERMINATED',
                message: 'Container no longer exists'
            })
        };
    }
    
    const task = tasksResult.tasks[0];
    const attachment = task.attachments?.[0];
    const eniId = attachment?.details?.find(d => d.name === 'networkInterfaceId')?.value;
    
    let publicIp = null;
    if (eniId && task.lastStatus === 'RUNNING') {
        // Get public IP
        const eniResult = await ec2.describeNetworkInterfaces({
            NetworkInterfaceIds: [eniId]
        }).promise();
        
        publicIp = eniResult.NetworkInterfaces[0]?.Association?.PublicIp;
        
        // Update session with IP
        if (publicIp && session.publicIp !== publicIp) {
            await dynamodb.update({
                TableName: SESSIONS_TABLE,
                Key: { sessionId },
                UpdateExpression: 'SET publicIp = :ip, #s = :status',
                ExpressionAttributeNames: { '#s': 'status' },
                ExpressionAttributeValues: {
                    ':ip': publicIp,
                    ':status': 'RUNNING'
                }
            }).promise();
        }
    }
    
    return {
        statusCode: 200,
        body: JSON.stringify({
            sessionId,
            status: task.lastStatus,
            publicIp,
            sshCommand: publicIp ? `ssh student@${publicIp}` : null,
            password: 'devops123',
            expiresIn: Math.max(0, session.expiresAt - Math.floor(Date.now() / 1000))
        })
    };
}

async function terminateContainer(sessionId) {
    // Get session
    const result = await dynamodb.get({
        TableName: SESSIONS_TABLE,
        Key: { sessionId }
    }).promise();
    
    if (!result.Item) {
        return {
            statusCode: 404,
            body: JSON.stringify({ error: 'Session not found' })
        };
    }
    
    // Stop the task
    await ecs.stopTask({
        cluster: CLUSTER_NAME,
        task: result.Item.taskArn,
        reason: 'User requested termination'
    }).promise();
    
    // Update session status
    await dynamodb.update({
        TableName: SESSIONS_TABLE,
        Key: { sessionId },
        UpdateExpression: 'SET #s = :status',
        ExpressionAttributeNames: { '#s': 'status' },
        ExpressionAttributeValues: { ':status': 'TERMINATED' }
    }).promise();
    
    return {
        statusCode: 200,
        body: JSON.stringify({
            message: 'Container terminated successfully'
        })
    };
}

async function checkExistingSession(userId) {
    const result = await dynamodb.query({
        TableName: SESSIONS_TABLE,
        IndexName: 'user-sessions-index',
        KeyConditionExpression: 'userId = :userId',
        FilterExpression: '#s IN (:s1, :s2)',
        ExpressionAttributeNames: { '#s': 'status' },
        ExpressionAttributeValues: {
            ':userId': userId,
            ':s1': 'PROVISIONING',
            ':s2': 'RUNNING'
        }
    }).promise();
    
    return result.Items[0];
}
EOF

# Create package.json
cat > container-lambda/package.json << 'EOF'
{
  "name": "container-management-lambda",
  "version": "1.0.0",
  "main": "index.js",
  "dependencies": {
    "aws-sdk": "^2.1472.0"
  }
}
EOF

# Package and deploy
cd container-lambda
npm install
zip -r function.zip .

# Create Lambda function
CONTAINER_LAMBDA_OUTPUT=$(aws lambda create-function \
  --function-name devops-bootcamp-containers \
  --runtime nodejs18.x \
  --role $LAMBDA_ROLE_ARN \
  --handler index.handler \
  --zip-file fileb://function.zip \
  --timeout 60 \
  --memory-size 512 \
  --environment Variables="{
    CLUSTER_NAME=$CLUSTER_NAME,
    SESSIONS_TABLE=$SESSIONS_TABLE,
    ECR_REPO_URI=$ECR_REPO_URI,
    TASK_EXECUTION_ROLE_ARN=$TASK_EXECUTION_ROLE_ARN
  }" \
  --output json)

CONTAINER_LAMBDA_ARN=$(echo $CONTAINER_LAMBDA_OUTPUT | jq -r '.FunctionArn')
echo "Container Lambda created: $CONTAINER_LAMBDA_ARN"

cd ..
```

## Step 7.7: Create VPC and Security Group

```bash
# Create VPC for containers (or use existing)
echo "Setting up VPC and security groups..."

# Check if default VPC exists
DEFAULT_VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)

if [ "$DEFAULT_VPC_ID" != "None" ]; then
    VPC_ID=$DEFAULT_VPC_ID
    echo "Using default VPC: $VPC_ID"
    
    # Get subnets
    SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text | tr '\t' ',')
else
    # Create new VPC
    VPC_OUTPUT=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --output json)
    VPC_ID=$(echo $VPC_OUTPUT | jq -r '.Vpc.VpcId')
    
    # Enable DNS
    aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
    
    # Create subnets
    SUBNET1_OUTPUT=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone ${REGION}a --output json)
    SUBNET2_OUTPUT=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone ${REGION}b --output json)
    
    SUBNET_IDS="$(echo $SUBNET1_OUTPUT | jq -r '.Subnet.SubnetId'),$(echo $SUBNET2_OUTPUT | jq -r '.Subnet.SubnetId')"
fi

# Create security group for containers
SG_OUTPUT=$(aws ec2 create-security-group \
  --group-name devops-bootcamp-containers \
  --description "Security group for DevOps Bootcamp challenge containers" \
  --vpc-id $VPC_ID \
  --output json 2>/dev/null || echo '{"GroupId": "existing"}')

if [[ "$SG_OUTPUT" == *"existing"* ]]; then
    SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=devops-bootcamp-containers" --query 'SecurityGroups[0].GroupId' --output text)
else
    SECURITY_GROUP_ID=$(echo $SG_OUTPUT | jq -r '.GroupId')
fi

# Add SSH access rule
aws ec2 authorize-security-group-ingress \
  --group-id $SECURITY_GROUP_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 \
  2>/dev/null || echo "SSH rule already exists"

echo "Security group configured: $SECURITY_GROUP_ID"

# Update container Lambda with VPC info
aws lambda update-function-configuration \
  --function-name devops-bootcamp-containers \
  --environment Variables="{
    CLUSTER_NAME=$CLUSTER_NAME,
    SESSIONS_TABLE=$SESSIONS_TABLE,
    ECR_REPO_URI=$ECR_REPO_URI,
    TASK_EXECUTION_ROLE_ARN=$TASK_EXECUTION_ROLE_ARN,
    SUBNET_IDS=$SUBNET_IDS,
    SECURITY_GROUP_ID=$SECURITY_GROUP_ID
  }" \
  --output json > /dev/null
```

## Step 7.8: Add Container Endpoints to API Gateway

```bash
# Create /api/containers resource
CONTAINERS_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $API_RESOURCE_ID \
  --path-part containers \
  --output json)

CONTAINERS_ID=$(echo $CONTAINERS_RESOURCE | jq -r '.id')

# Create methods
create_method $CONTAINERS_ID "POST" false

# Add Lambda integration
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $CONTAINERS_ID \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${REGION}:$(aws sts get-caller-identity --query Account --output text):function:devops-bootcamp-containers/invocations" \
  --output json > /dev/null

# Add permission for API Gateway to invoke container Lambda
aws lambda add-permission \
  --function-name devops-bootcamp-containers \
  --statement-id APIGatewayInvokeContainers \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${REGION}:*:${API_ID}/*/*" \
  2>/dev/null || echo "Permission may already exist"

# Enable CORS
enable_cors $CONTAINERS_ID

# Deploy API changes
aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name $API_STAGE \
  --description "Added container endpoints" \
  --output json > /dev/null

echo "Container API endpoints added"
```

## Step 7.9: Update Dashboard with Container Launch

```bash
# Create enhanced dashboard with container launching
cat > dashboard-containers.html << 'EOF'
<!-- Add this section to your existing dashboard.html -->

<style>
    .container-status {
        background: #1a1a1a;
        border: 2px solid #333;
        border-radius: 15px;
        padding: 2rem;
        margin-top: 2rem;
        display: none;
    }
    
    .container-status.active {
        display: block;
        animation: slideIn 0.5s;
    }
    
    .ssh-command {
        background: #0a0a0a;
        padding: 1rem;
        border-radius: 8px;
        font-family: monospace;
        margin: 1rem 0;
        display: flex;
        align-items: center;
        justify-content: space-between;
    }
    
    .copy-button {
        background: #00ff88;
        color: #0a0a0a;
        border: none;
        padding: 0.5rem 1rem;
        border-radius: 5px;
        cursor: pointer;
        font-weight: bold;
    }
    
    .status-indicator {
        display: inline-block;
        width: 12px;
        height: 12px;
        border-radius: 50%;
        margin-right: 0.5rem;
        animation: pulse 2s infinite;
    }
    
    .status-indicator.provisioning {
        background: #ff9800;
    }
    
    .status-indicator.running {
        background: #00ff88;
    }
    
    .status-indicator.terminated {
        background: #f44336;
    }
    
    .terminal-preview {
        background: #000;
        color: #00ff88;
        padding: 1rem;
        border-radius: 8px;
        margin-top: 1rem;
        font-family: monospace;
        min-height: 200px;
    }
</style>

<script>
let activeSession = null;
let statusCheckInterval = null;

async function startChallenge(challenge) {
    // Check if user already has an active session
    if (activeSession) {
        showMessage('You already have an active container session', 'error');
        return;
    }
    
    showMessage(`Launching container for: ${challenge.name}`, 'info');
    
    try {
        const response = await fetch(`${API_ENDPOINT}/api/containers`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': authToken
            },
            body: JSON.stringify({
                action: 'launch',
                userId: currentUser.attributes.sub,
                challengeId: challenge.id
            })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            activeSession = data.sessionId;
            showContainerStatus(data);
            startStatusChecking();
        } else {
            showMessage(data.error || 'Failed to launch container', 'error');
        }
    } catch (error) {
        showMessage('Error launching container: ' + error.message, 'error');
    }
}

function showContainerStatus(status) {
    let statusHTML = `
        <div class="container-status active" id="containerStatus">
            <h3>
                <span class="status-indicator ${status.status.toLowerCase()}"></span>
                Container Status: ${status.status}
            </h3>
    `;
    
    if (status.status === 'PROVISIONING') {
        statusHTML += `
            <p>Your container is being prepared. This usually takes 30-60 seconds...</p>
            <div class="loading-bar">
                <div class="loading-progress"></div>
            </div>
        `;
    } else if (status.status === 'RUNNING' && status.publicIp) {
        statusHTML += `
            <p>✅ Your container is ready!</p>
            <div class="ssh-command">
                <code id="sshCommand">${status.sshCommand}</code>
                <button class="copy-button" onclick="copySSHCommand()">Copy</button>
            </div>
            <p><strong>Password:</strong> <code>${status.password}</code></p>
            <p><strong>Time remaining:</strong> <span id="timeRemaining">${formatTime(status.expiresIn)}</span></p>
            
            <div class="terminal-preview">
                <p>💡 Quick Start:</p>
                <p>1. Copy the SSH command above</p>
                <p>2. Open your terminal (Command Prompt on Windows, Terminal on Mac/Linux)</p>
                <p>3. Paste and run the command</p>
                <p>4. Enter the password when prompted</p>
            </div>
            
            <button class="btn" style="background: #ff0088; margin-top: 1rem;" onclick="terminateContainer()">
                Terminate Container
            </button>
        `;
    } else if (status.status === 'TERMINATED') {
        statusHTML += `
            <p>Container has been terminated.</p>
            <button class="btn" onclick="hideContainerStatus()">Close</button>
        `;
        activeSession = null;
        stopStatusChecking();
    }
    
    statusHTML += '</div>';
    
    // Insert or update the status section
    const existingStatus = document.getElementById('containerStatus');
    if (existingStatus) {
        existingStatus.outerHTML = statusHTML;
    } else {
        const challengesSection = document.querySelector('.challenges-section');
        challengesSection.insertAdjacentHTML('afterend', statusHTML);
    }
}

async function checkContainerStatus() {
    if (!activeSession) return;
    
    try {
        const response = await fetch(`${API_ENDPOINT}/api/containers`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': authToken
            },
            body: JSON.stringify({
                action: 'status',
                sessionId: activeSession
            })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            showContainerStatus(data);
            
            // Update time remaining
            if (data.expiresIn > 0) {
                document.getElementById('timeRemaining').textContent = formatTime(data.expiresIn);
            }
        }
    } catch (error) {
        console.error('Error checking status:', error);
    }
}

function startStatusChecking() {
    // Check immediately
    checkContainerStatus();
    
    // Then check every 5 seconds
    statusCheckInterval = setInterval(checkContainerStatus, 5000);
}

function stopStatusChecking() {
    if (statusCheckInterval) {
        clearInterval(statusCheckInterval);
        statusCheckInterval = null;
    }
}

async function terminateContainer() {
    if (!activeSession) return;
    
    if (confirm('Are you sure you want to terminate this container?')) {
        try {
            const response = await fetch(`${API_ENDPOINT}/api/containers`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': authToken
                },
                body: JSON.stringify({
                    action: 'terminate',
                    sessionId: activeSession
                })
            });
            
            if (response.ok) {
                showMessage('Container terminated', 'success');
                showContainerStatus({ status: 'TERMINATED' });
            }
        } catch (error) {
            showMessage('Error terminating container', 'error');
        }
    }
}

function copySSHCommand() {
    const command = document.getElementById('sshCommand').textContent;
    navigator.clipboard.writeText(command).then(() => {
        showMessage('SSH command copied to clipboard!', 'success');
    });
}

function hideContainerStatus() {
    const status = document.getElementById('containerStatus');
    if (status) {
        status.classList.remove('active');
        setTimeout(() => status.remove(), 500);
    }
}

function formatTime(seconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return `${hours}h ${minutes}m`;
}

// Update the createChallengeCard function to launch containers
function createChallengeCard(challenge) {
    const card = document.createElement('div');
    card.className = 'challenge-card';
    
    // Check if completed (mock for now)
    const isCompleted = Math.random() > 0.7;
    const isLocked = challenge.level > 2 && !isCompleted;
    
    if (isCompleted) card.classList.add('completed');
    if (isLocked) card.classList.add('locked');
    
    card.innerHTML = `
        <div class="challenge-header">
            <span class="challenge-level">Level ${challenge.level}</span>
            <span class="challenge-points">${isCompleted ? '✓' : ''} ${challenge.points} pts</span>
        </div>
        <h3 class="challenge-title">${challenge.name}</h3>
        <p class="challenge-description">${challenge.description}</p>
        <span class="difficulty-badge difficulty-${challenge.difficulty}">${challenge.difficulty}</span>
        ${isLocked ? '<div style="margin-top: 1rem; color: #888;">🔒 Complete prerequisites first</div>' : ''}
        ${!isLocked && !isCompleted ? '<button class="btn" style="margin-top: 1rem; width: 100%;">Start Challenge</button>' : ''}
    `;
    
    if (!isLocked && !isCompleted) {
        card.querySelector('button').onclick = () => startChallenge(challenge);
    }
    
    return card;
}
</script>
EOF

# Merge with existing dashboard
echo "Container launching UI added to dashboard"
```

## Step 7.10: Create CloudWatch Log Group

```bash
# Create log group for ECS tasks
aws logs create-log-group \
  --log-group-name /ecs/devops-bootcamp \
  --tags Project=DevOpsBootcamp \
  2>/dev/null || echo "Log group already exists"

# Set retention
aws logs put-retention-policy \
  --log-group-name /ecs/devops-bootcamp \
  --retention-in-days 7
```

## Step 7.11: Add ECS Permissions to Lambda

```bash
# Create ECS policy for Lambda
cat > ecs-lambda-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:RegisterTaskDefinition",
        "ecs:RunTask",
        "ecs:StopTask",
        "ecs:DescribeTasks",
        "ec2:DescribeNetworkInterfaces",
        "iam:PassRole"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:${REGION}:*:log-group:/ecs/devops-bootcamp:*"
    }
  ]
}
EOF

# Attach to container Lambda
aws iam put-role-policy \
  --role-name $LAMBDA_ROLE_NAME \
  --policy-name ECSAccess
