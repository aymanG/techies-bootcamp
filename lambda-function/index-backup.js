// Lambda function handler
const AWS = require('aws-sdk');
const cognito = new AWS.CognitoIdentityServiceProvider();
const dynamodb = new AWS.DynamoDB.DocumentClient();

// Table name (we'll create this in Step 6)
const USERS_TABLE = process.env.USERS_TABLE || 'devops-bootcamp-users';

// CORS headers for browser access
const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
};

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    // Handle preflight requests
    if (event.requestContext?.http?.method === 'OPTIONS' || event.httpMethod === 'OPTIONS') {
        return {
            statusCode: 200,
            headers: corsHeaders,
            body: ''
        };
    }
    
    try {
        // Get path - Function URLs use rawPath, API Gateway uses path
        let path = event.rawPath || event.path || '/';
        
        // Remove stage name if present (for API Gateway)
        path = path.replace(/^\/[^\/]+\//, '/');
        
        // Get method
        const method = event.requestContext?.http?.method || event.httpMethod || 'GET';
        
        // Get authorization token
        const token = event.headers?.Authorization || event.headers?.authorization || '';
        
        console.log('Processing:', method, path);
        
        // Route the request
        let response;
        
        if (path === '/' || path === '') {
            response = {
                statusCode: 200,
                body: JSON.stringify({ 
                    message: 'DevOps Bootcamp API',
                    endpoints: [
                        'GET /api/health',
                        'GET /api/challenges',
                        'GET /api/user/profile (auth required)',
                        'GET /api/user/progress (auth required)',
                        'POST /api/user/progress (auth required)'
                    ]
                })
            };
        } else if (path === '/api/health' || path.endsWith('/api/health')) {
            response = await handleHealth();
        } else if ((path === '/api/user/profile' || path.endsWith('/api/user/profile')) && method === 'GET') {
            response = await handleGetProfile(token);
        } else if ((path === '/api/user/progress' || path.endsWith('/api/user/progress')) && method === 'GET') {
            response = await handleGetProgress(token);
        } else if ((path === '/api/user/progress' || path.endsWith('/api/user/progress')) && method === 'POST') {
            response = await handleUpdateProgress(token, JSON.parse(event.body || '{}'));
        } else if (path === '/api/challenges' || path.endsWith('/api/challenges')) {
            response = await handleGetChallenges();
        } else {
            response = {
                statusCode: 404,
                body: JSON.stringify({ 
                    error: 'Not found',
                    path: path,
                    method: method
                })
            };
        }
        
        // Add CORS headers to response
        response.headers = { ...corsHeaders, ...response.headers };
        return response;
        
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            headers: corsHeaders,
            body: JSON.stringify({ 
                error: error.message || 'Internal server error',
                stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
            })
        };
    }
};

// Health check endpoint
async function handleHealth() {
    return {
        statusCode: 200,
        body: JSON.stringify({
            status: 'healthy',
            timestamp: new Date().toISOString(),
            service: 'devops-bootcamp-api',
            version: '1.0.0'
        })
    };
}

// Get user profile from token
async function handleGetProfile(token) {
    if (!token || token === 'YOUR_JWT_TOKEN_HERE') {
        return {
            statusCode: 401,
            body: JSON.stringify({ error: 'No valid authorization token' })
        };
    }
    
    try {
        // Decode the JWT token to get user info
        const tokenParts = token.split('.');
        if (tokenParts.length !== 3) {
            throw new Error('Invalid token format');
        }
        
        const payload = JSON.parse(Buffer.from(tokenParts[1], 'base64').toString());
        const email = payload.email || payload['cognito:username'];
        const sub = payload.sub;
        
        // Get or create user record in DynamoDB
        try {
            const result = await dynamodb.get({
                TableName: USERS_TABLE,
                Key: { userId: sub }
            }).promise();
            
            if (result.Item) {
                return {
                    statusCode: 200,
                    body: JSON.stringify(result.Item)
                };
            }
        } catch (dbError) {
            console.log('DynamoDB not set up yet, returning basic profile');
        }
        
        // Return basic profile if no DynamoDB record
        const profile = {
            userId: sub,
            email: email,
            points: 0,
            rank: 'Novice',
            completedChallenges: [],
            createdAt: new Date().toISOString()
        };
        
        return {
            statusCode: 200,
            body: JSON.stringify(profile)
        };
        
    } catch (error) {
        console.error('Profile error:', error);
        return {
            statusCode: 401,
            body: JSON.stringify({ error: 'Invalid token' })
        };
    }
}

// Get user progress
async function handleGetProgress(token) {
    if (!token) {
        return {
            statusCode: 401,
            body: JSON.stringify({ error: 'No authorization token' })
        };
    }
    
    // For now, return mock progress
    const progress = {
        totalPoints: 0,
        completedChallenges: [],
        currentStreak: 0,
        lastActivity: new Date().toISOString()
    };
    
    return {
        statusCode: 200,
        body: JSON.stringify(progress)
    };
}

// Update user progress
async function handleUpdateProgress(token, data) {
    if (!token) {
        return {
            statusCode: 401,
            body: JSON.stringify({ error: 'No authorization token' })
        };
    }
    
    console.log('Update progress:', data);
    
    return {
        statusCode: 200,
        body: JSON.stringify({
            success: true,
            message: 'Progress updated',
            points: data.points || 0
        })
    };
}

// Get available challenges
async function handleGetChallenges() {
    // Static challenge data for now
    const challenges = [
        {
            id: 'welcome',
            name: 'Welcome to DevOps Academy',
            description: 'Get familiar with the platform and access your first container',
            level: 0,
            difficulty: 'beginner',
            points: 10,
            category: 'basics',
            prerequisites: []
        },
        {
            id: 'terminal-basics',
            name: 'Terminal Navigation',
            description: 'Master basic terminal commands: ls, cd, pwd, cat',
            level: 1,
            difficulty: 'beginner',
            points: 20,
            category: 'linux',
            prerequisites: ['welcome']
        },
        {
            id: 'file-permissions',
            name: 'File Permissions',
            description: 'Understand and modify file permissions using chmod',
            level: 2,
            difficulty: 'intermediate',
            points: 30,
            category: 'linux',
            prerequisites: ['terminal-basics']
        },
        {
            id: 'shell-scripting',
            name: 'Shell Scripting Basics',
            description: 'Write your first bash scripts',
            level: 3,
            difficulty: 'intermediate',
            points: 40,
            category: 'linux',
            prerequisites: ['file-permissions']
        },
        {
            id: 'docker-intro',
            name: 'Introduction to Docker',
            description: 'Learn containerization basics',
            level: 4,
            difficulty: 'advanced',
            points: 50,
            category: 'docker',
            prerequisites: ['shell-scripting']
        }
    ];
    
    return {
        statusCode: 200,
        body: JSON.stringify({
            challenges: challenges,
            total: challenges.length
        })
    };
}
