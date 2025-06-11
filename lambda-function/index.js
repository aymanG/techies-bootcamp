const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

// Table names from environment
const USERS_TABLE = process.env.USERS_TABLE || 'devops-bootcamp-users';
const CHALLENGES_TABLE = process.env.CHALLENGES_TABLE || 'devops-bootcamp-challenges';
const PROGRESS_TABLE = process.env.PROGRESS_TABLE || 'devops-bootcamp-progress';
const SESSIONS_TABLE = process.env.SESSIONS_TABLE || 'devops-bootcamp-sessions';

// CORS headers
const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
};

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    const path = event.path || '/';
    const method = event.httpMethod || 'GET';
    const authHeader = event.headers?.Authorization || event.headers?.authorization || '';
    
    try {
        let response;
        
        // Route requests
        switch (true) {
            case path === '/api/health':
                response = await handleHealth();
                break;
                
            case path === '/api/challenges' && method === 'GET':
                response = await handleGetChallenges();
                break;
                
            case path === '/api/user/profile' && method === 'GET':
                response = await handleGetProfile(authHeader);
                break;
                
            case path === '/api/user/profile' && method === 'PUT':
                response = await handleUpdateProfile(authHeader, JSON.parse(event.body || '{}'));
                break;
                
            case path === '/api/user/progress' && method === 'GET':
                response = await handleGetProgress(authHeader);
                break;
                
            case path === '/api/user/progress' && method === 'POST':
                response = await handleUpdateProgress(authHeader, JSON.parse(event.body || '{}'));
                break;
                
            case path === '/api/leaderboard' && method === 'GET':
                response = await handleGetLeaderboard();
                break;
                
            default:
                response = {
                    statusCode: 404,
                    body: JSON.stringify({ error: 'Not found' })
                };
        }
        
        return { ...response, headers };
        
    } catch (error) {
        console.error('Handler error:', error);
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({ 
                error: 'Internal server error',
                message: error.message 
            })
        };
    }
};

// Health check
async function handleHealth() {
    // Check DynamoDB connectivity
    try {
        await dynamodb.scan({
            TableName: USERS_TABLE,
            Limit: 1
        }).promise();
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                status: 'healthy',
                timestamp: new Date().toISOString(),
                service: 'devops-bootcamp-api',
                version: '2.0.0',
                database: 'connected'
            })
        };
    } catch (error) {
        return {
            statusCode: 200,
            body: JSON.stringify({
                status: 'degraded',
                timestamp: new Date().toISOString(),
                service: 'devops-bootcamp-api',
                version: '2.0.0',
                database: 'error',
                error: error.message
            })
        };
    }
}

// Get challenges from DynamoDB
async function handleGetChallenges() {
    try {
        const result = await dynamodb.scan({
            TableName: CHALLENGES_TABLE,
            FilterExpression: 'isActive = :active',
            ExpressionAttributeValues: {
                ':active': true
            },
            ProjectionExpression: 'challengeId, #n, description, category, #l, difficulty, points, prerequisites, skills',
            ExpressionAttributeNames: {
                '#n': 'name',
                '#l': 'level'
            }
        }).promise();
        
        // Sort by level and category
        const challenges = result.Items.sort((a, b) => {
            if (a.level !== b.level) return a.level - b.level;
            return a.category.localeCompare(b.category);
        });
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                challenges,
                total: challenges.length,
                categories: [...new Set(challenges.map(c => c.category))]
            })
        };
    } catch (error) {
        console.error('Error fetching challenges:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Failed to fetch challenges' })
        };
    }
}

// Get user profile
async function handleGetProfile(authHeader) {
    const userId = await getUserIdFromToken(authHeader);
    if (!userId) {
        return {
            statusCode: 401,
            body: JSON.stringify({ error: 'Unauthorized' })
        };
    }
    
    try {
        // Get user from DynamoDB
        const userResult = await dynamodb.get({
            TableName: USERS_TABLE,
            Key: { userId }
        }).promise();
        
        if (!userResult.Item) {
            // Create new user profile
            const tokenData = decodeToken(authHeader);
            const newUser = {
                userId,
                email: tokenData.email,
                displayName: tokenData.email.split('@')[0],
                rank: 'Novice',
                points: 0,
                completedChallenges: 0,
                totalTimeSpent: 0,
                achievements: [],
                streak: 0,
                lastActiveDate: new Date().toISOString().split('T')[0],
                joinedAt: new Date().toISOString(),
                preferences: {
                    theme: 'dark',
                    notifications: true
                }
            };
            
            await dynamodb.put({
                TableName: USERS_TABLE,
                Item: newUser
            }).promise();
            
            return {
                statusCode: 200,
                body: JSON.stringify(newUser)
            };
        }
        
        // Update last active
        await updateLastActive(userId);
        
        return {
            statusCode: 200,
            body: JSON.stringify(userResult.Item)
        };
        
    } catch (error) {
        console.error('Error getting profile:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Failed to get profile' })
        };
    }
}

// Update user profile
async function handleUpdateProfile(authHeader, updates) {
    const userId = await getUserIdFromToken(authHeader);
    if (!userId) {
        return {
            statusCode: 401,
            body: JSON.stringify({ error: 'Unauthorized' })
        };
    }
    
    try {
        // Whitelist allowed updates
        const allowedFields = ['displayName', 'avatar', 'bio', 'preferences'];
        const updateExpression = [];
        const expressionValues = {};
        const expressionNames = {};
        
        Object.keys(updates).forEach(key => {
            if (allowedFields.includes(key)) {
                updateExpression.push(`#${key} = :${key}`);
                expressionValues[`:${key}`] = updates[key];
                expressionNames[`#${key}`] = key;
            }
        });
        
        if (updateExpression.length === 0) {
            return {
                statusCode: 400,
                body: JSON.stringify({ error: 'No valid fields to update' })
            };
        }
        
        // Add updatedAt
        updateExpression.push('#updatedAt = :updatedAt');
        expressionValues[':updatedAt'] = new Date().toISOString();
        expressionNames['#updatedAt'] = 'updatedAt';
        
        const result = await dynamodb.update({
            TableName: USERS_TABLE,
            Key: { userId },
            UpdateExpression: `SET ${updateExpression.join(', ')}`,
            ExpressionAttributeValues: expressionValues,
            ExpressionAttributeNames: expressionNames,
            ReturnValues: 'ALL_NEW'
        }).promise();
        
        return {
            statusCode: 200,
            body: JSON.stringify(result.Attributes)
        };
        
    } catch (error) {
        console.error('Error updating profile:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Failed to update profile' })
        };
    }
}

// Get user progress
async function handleGetProgress(authHeader) {
    const userId = await getUserIdFromToken(authHeader);
    if (!userId) {
        return {
            statusCode: 401,
            body: JSON.stringify({ error: 'Unauthorized' })
        };
    }
    
    try {
        // Get all progress for user
        const progressResult = await dynamodb.query({
            TableName: PROGRESS_TABLE,
            KeyConditionExpression: 'userId = :userId',
            ExpressionAttributeValues: {
                ':userId': userId
            }
        }).promise();
        
        // Calculate statistics
        const completedChallenges = progressResult.Items.filter(p => p.status === 'completed');
        const totalPoints = completedChallenges.reduce((sum, p) => sum + (p.pointsEarned || 0), 0);
        const totalTimeSpent = completedChallenges.reduce((sum, p) => sum + (p.timeSpent || 0), 0);
        
        // Get current streak
        const streak = await calculateStreak(userId, progressResult.Items);
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                progress: progressResult.Items,
                statistics: {
                    totalPoints,
                    completedCount: completedChallenges.length,
                    totalTimeSpent,
                    averageTime: completedChallenges.length > 0 ? 
                        Math.round(totalTimeSpent / completedChallenges.length) : 0,
                    streak,
                    lastActivity: progressResult.Items.length > 0 ?
                        progressResult.Items.sort((a, b) => 
                            new Date(b.updatedAt) - new Date(a.updatedAt))[0].updatedAt :
                        null
                }
            })
        };
        
    } catch (error) {
        console.error('Error getting progress:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Failed to get progress' })
        };
    }
}

// Update challenge progress
async function handleUpdateProgress(authHeader, data) {
    const userId = await getUserIdFromToken(authHeader);
    if (!userId) {
        return {
            statusCode: 401,
            body: JSON.stringify({ error: 'Unauthorized' })
        };
    }
    
    const { challengeId, status, timeSpent, hintsUsed = 0 } = data;
    
    if (!challengeId || !status) {
        return {
            statusCode: 400,
            body: JSON.stringify({ error: 'Missing required fields' })
        };
    }
    
    try {
        // Get challenge details
        const challengeResult = await dynamodb.get({
            TableName: CHALLENGES_TABLE,
            Key: { challengeId }
        }).promise();
        
        if (!challengeResult.Item) {
            return {
                statusCode: 404,
                body: JSON.stringify({ error: 'Challenge not found' })
            };
        }
        
        const challenge = challengeResult.Item;
        const timestamp = new Date().toISOString();
        
        // Calculate points (reduce for hints used)
        let pointsEarned = 0;
        if (status === 'completed') {
            pointsEarned = Math.max(
                challenge.points - (hintsUsed * 5),
                Math.floor(challenge.points * 0.3) // Minimum 30% points
            );
        }
        
        // Update progress
        await dynamodb.put({
            TableName: PROGRESS_TABLE,
            Item: {
                userId,
                challengeId,
                status,
                attempts: data.attempts || 1,
                startedAt: data.startedAt || timestamp,
                completedAt: status === 'completed' ? timestamp : null,
                timeSpent,
                hintsUsed,
                pointsEarned,
                updatedAt: timestamp
            }
        }).promise();
        
        // Update user stats if completed
        if (status === 'completed') {
            await updateUserStats(userId, pointsEarned, challengeId);
        }
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                success: true,
                pointsEarned,
                newStatus: status,
                timestamp
            })
        };
        
    } catch (error) {
        console.error('Error updating progress:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Failed to update progress' })
        };
    }
}

// Get leaderboard
async function handleGetLeaderboard() {
    try {
        // Get top users by rank and points
        const noviceLeaders = await getLeadersByRank('Novice', 10);
        const apprenticeLeaders = await getLeadersByRank('Apprentice', 10);
        const expertLeaders = await getLeadersByRank('Expert', 10);
        
        // Get global top 20
        const globalResult = await dynamodb.scan({
            TableName: USERS_TABLE,
            ProjectionExpression: 'userId, displayName, email, points, #r, completedChallenges, avatar',
            ExpressionAttributeNames: {
                '#r': 'rank'
            }
        }).promise();
        
        const globalLeaders = globalResult.Items
            .sort((a, b) => b.points - a.points)
            .slice(0, 20)
            .map((user, index) => ({
                ...user,
                position: index + 1,
                displayName: user.displayName || user.email.split('@')[0]
            }));
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                global: globalLeaders,
                byRank: {
                    novice: noviceLeaders,
                    apprentice: apprenticeLeaders,
                    expert: expertLeaders
                },
                lastUpdated: new Date().toISOString()
            })
        };
        
    } catch (error) {
        console.error('Error getting leaderboard:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Failed to get leaderboard' })
        };
    }
}

// Helper functions
async function getUserIdFromToken(authHeader) {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return null;
    }
    
    try {
        const token = authHeader.replace('Bearer ', '');
        const decoded = decodeToken(authHeader);
        return decoded.sub;
    } catch (error) {
        return null;
    }
}

function decodeToken(authHeader) {
    const token = authHeader.replace('Bearer ', '');
    const parts = token.split('.');
    if (parts.length !== 3) {
        throw new Error('Invalid token format');
    }
    return JSON.parse(Buffer.from(parts[1], 'base64').toString());
}

async function updateUserStats(userId, pointsToAdd, challengeId) {
    try {
        const result = await dynamodb.update({
            TableName: USERS_TABLE,
            Key: { userId },
            UpdateExpression: `
                SET points = points + :points,
                    completedChallenges = completedChallenges + :one,
                    lastActiveDate = :today,
                    updatedAt = :now
                ADD completedChallengesList :challenge
            `,
            ExpressionAttributeValues: {
                ':points': pointsToAdd,
                ':one': 1,
                ':today': new Date().toISOString().split('T')[0],
                ':now': new Date().toISOString(),
                ':challenge': dynamodb.createSet([challengeId])
            },
            ReturnValues: 'ALL_NEW'
        }).promise();
        
        // Check for rank upgrade
        await checkRankUpgrade(userId, result.Attributes.points);
        
    } catch (error) {
        console.error('Error updating user stats:', error);
    }
}

async function checkRankUpgrade(userId, totalPoints) {
    const ranks = [
        { name: 'Novice', minPoints: 0 },
        { name: 'Apprentice', minPoints: 100 },
        { name: 'Practitioner', minPoints: 500 },
        { name: 'Expert', minPoints: 1500 },
        { name: 'Master', minPoints: 3000 },
        { name: 'Architect', minPoints: 5000 }
    ];
    
    const newRank = ranks.reverse().find(r => totalPoints >= r.minPoints).name;
    
    await dynamodb.update({
        TableName: USERS_TABLE,
        Key: { userId },
        UpdateExpression: 'SET #r = :rank',
        ExpressionAttributeNames: { '#r': 'rank' },
        ExpressionAttributeValues: { ':rank': newRank }
    }).promise();
}

async function calculateStreak(userId, progressItems) {
    const completedDates = progressItems
        .filter(p => p.status === 'completed' && p.completedAt)
        .map(p => p.completedAt.split('T')[0])
        .sort()
        .reverse();
    
    if (completedDates.length === 0) return 0;
    
    let streak = 1;
    const today = new Date().toISOString().split('T')[0];
    
    if (completedDates[0] !== today) {
        const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];
        if (completedDates[0] !== yesterday) return 0;
    }
    
    for (let i = 1; i < completedDates.length; i++) {
        const prevDate = new Date(completedDates[i - 1]);
        const currDate = new Date(completedDates[i]);
        const diffDays = Math.floor((prevDate - currDate) / 86400000);
        
        if (diffDays === 1) {
            streak++;
        } else {
            break;
        }
    }
    
    return streak;
}

async function updateLastActive(userId) {
    const today = new Date().toISOString().split('T')[0];
    await dynamodb.update({
        TableName: USERS_TABLE,
        Key: { userId },
        UpdateExpression: 'SET lastActiveDate = :today',
        ExpressionAttributeValues: { ':today': today }
    }).promise();
}

async function getLeadersByRank(rank, limit) {
    try {
        const result = await dynamodb.query({
            TableName: USERS_TABLE,
            IndexName: 'rank-points-index',
            KeyConditionExpression: '#r = :rank',
            ExpressionAttributeNames: { '#r': 'rank' },
            ExpressionAttributeValues: { ':rank': rank },
            ScanIndexForward: false,
            Limit: limit
        }).promise();
        
        return result.Items.map((user, index) => ({
            ...user,
            position: index + 1,
            displayName: user.displayName || user.email.split('@')[0]
        }));
    } catch (error) {
        console.error(`Error getting ${rank} leaders:`, error);
        return [];
    }
}
