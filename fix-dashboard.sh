#!/bin/bash

# Download current dashboard
aws s3 cp s3://$BUCKET_NAME/dashboard.html dashboard-current.html

# Create the fix by replacing the startChallenge function
# This is a simplified fix - you may need to manually edit the file
perl -i -pe 'BEGIN{undef $/;} s/async function startChallenge\(challenge\).*?^\}/async function startChallenge(challenge) {
    if (activeSession) {
        showMessage("You already have an active container session", "error");
        return;
    }
    
    const cognitoUser = userPool.getCurrentUser();
    if (!cognitoUser) {
        showMessage("Please login first", "error");
        return;
    }
    
    cognitoUser.getSession(async (err, session) => {
        if (err || !session.isValid()) {
            showMessage("Session expired, please login again", "error");
            return;
        }
        
        const userId = session.getIdToken().payload.sub;
        showMessage(`Launching container for: ${challenge.name}`, "info");
        
        try {
            const response = await fetch(`${API_ENDPOINT}\/api\/containers`, {
                method: "POST",
                headers: {
                    "Content-Type": "application\/json",
                    "Authorization": authToken
                },
                body: JSON.stringify({
                    action: "launch",
                    userId: userId,
                    challengeId: challenge.id || challenge.challengeId
                })
            });
            
            const data = await response.json();
            
            if (response.ok) {
                activeSession = data.sessionId;
                showContainerStatus(data);
                startStatusChecking();
            } else {
                showMessage(data.error || "Failed to launch container", "error");
            }
        } catch (error) {
            showMessage("Error launching container: " + error.message, "error");
        }
    });
}/smg' dashboard-current.html

# Upload fixed version
aws s3 cp dashboard-current.html s3://$BUCKET_NAME/dashboard.html
aws s3 cp dashboard-current.html s3://$BUCKET_NAME/index.html

# Invalidate cache
aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/*"
