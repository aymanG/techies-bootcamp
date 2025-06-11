exports.handler = async (event) => {
    console.log('Full event:', JSON.stringify(event, null, 2));
    
    // Get the actual path from the event
    const rawPath = event.rawPath || event.path || '/';
    
    return {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({
            message: 'Debug info',
            receivedPath: rawPath,
            pathFromEvent: event.path,
            rawPathFromEvent: event.rawPath,
            resource: event.resource,
            allPaths: {
                path: event.path,
                rawPath: event.rawPath,
                resource: event.resource,
                pathParameters: event.pathParameters
            }
        })
    };
};
