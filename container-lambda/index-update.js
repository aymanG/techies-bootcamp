// Add this at the beginning of the handler function
exports.handler = async (event) => {
    console.log('Container Lambda Event:', JSON.stringify(event, null, 2));
    
    // Parse body - handle both string and object
    let body;
    try {
        body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    } catch (error) {
        return {
            statusCode: 400,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({ error: 'Invalid request body' })
        };
    }
    
    const { action, userId, challengeId, sessionId } = body;
    
    // Validate required fields
    if (!action) {
        return {
            statusCode: 400,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({ error: 'Action is required' })
        };
    }
    
    if (action === 'launch' && (!userId || !challengeId)) {
        return {
            statusCode: 400,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({ 
                error: 'userId and challengeId are required for launch action',
                received: { userId, challengeId }
            })
        };
    }
    
    // Continue with the rest of the function...
