// Add this to the containerDefinitions in your Lambda
portMappings: [
    {
        containerPort: 22,
        protocol: 'tcp'
    },
    {
        containerPort: 3000,
        protocol: 'tcp'
    }
]
