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
