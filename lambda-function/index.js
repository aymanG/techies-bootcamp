exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    // Standard response headers
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    };
    
    try {
        // Get path and method from API Gateway event structure
        const path = event.path || event.rawPath || '/';
        const method = event.httpMethod || event.requestContext?.http?.method || 'GET';
        
        console.log(`Processing: ${method} ${path}`);
        
        // Route based on path
        let body;
        let statusCode = 200;
        
        switch (path) {
            case '/api/health':
                body = {
                    status: 'healthy',
                    timestamp: new Date().toISOString(),
                    service: 'devops-bootcamp-api',
                    version: '1.0.0'
                };
                break;
                
            case '/api/challenges':
                body = {
                    challenges: [
                        {
                            id: 'welcome',
                            name: 'Welcome to DevOps Academy',
                            description: 'Get familiar with the platform',
                            level: 0,
                            difficulty: 'beginner',
                            points: 10,
                            category: 'basics',
                            prerequisites: []
                        },
                        {
                            id: 'terminal-basics',
                            name: 'Terminal Navigation',
                            description: 'Master basic terminal commands',
                            level: 1,
                            difficulty: 'beginner',
                            points: 20,
                            category: 'linux',
                            prerequisites: ['welcome']
                        },
                        {
                            id: 'file-permissions',
                            name: 'File Permissions',
                            description: 'Understand and modify file permissions',
                            level: 2,
                            difficulty: 'intermediate',
                            points: 30,
                            category: 'linux',
                            prerequisites: ['terminal-basics']
                        }
                    ],
                    total: 3
                };
                break;
                
            case '/api/user/profile':
                const authHeader = event.headers?.Authorization || event.headers?.authorization;
                
                if (!authHeader) {
                    statusCode = 401;
                    body = { error: 'No authorization token provided' };
                } else {
                    try {
                        // Basic JWT decode (without verification for now)
                        const token = authHeader.replace('Bearer ', '');
                        const parts = token.split('.');
                        if (parts.length === 3) {
                            const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString());
                            body = {
                                userId: payload.sub,
                                email: payload.email || payload['cognito:username'],
                                points: 0,
                                rank: 'Novice',
                                completedChallenges: [],
                                createdAt: new Date().toISOString()
                            };
                        } else {
                            statusCode = 401;
                            body = { error: 'Invalid token format' };
                        }
                    } catch (e) {
                        statusCode = 401;
                        body = { error: 'Invalid token' };
                    }
                }
                break;
                
            case '/api/user/progress':
                if (method === 'GET') {
                    body = {
                        totalPoints: 0,
                        completedChallenges: [],
                        currentStreak: 0,
                        lastActivity: new Date().toISOString()
                    };
                } else if (method === 'POST') {
                    body = {
                        success: true,
                        message: 'Progress updated'
                    };
                } else {
                    statusCode = 405;
                    body = { error: 'Method not allowed' };
                }
                break;
                
            default:
                statusCode = 404;
                body = { 
                    error: 'Not found',
                    path: path,
                    method: method
                };
        }
        
        // Return API Gateway response format
        return {
            statusCode: statusCode,
            headers: headers,
            body: JSON.stringify(body)
        };
        
    } catch (error) {
        console.error('Handler error:', error);
        return {
            statusCode: 500,
            headers: headers,
            body: JSON.stringify({
                error: 'Internal server error',
                message: error.message
            })
        };
    }
};
