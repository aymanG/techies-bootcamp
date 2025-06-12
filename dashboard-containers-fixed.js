let activeSession = null;
let statusCheckInterval = null;
let currentUserId = null;

// Function to get user ID properly
function getUserId(callback) {
    const cognitoUser = userPool.getCurrentUser();
    
    if (!cognitoUser) {
        callback(null);
        return;
    }
    
    cognitoUser.getSession((err, session) => {
        if (err || !session.isValid()) {
            callback(null);
            return;
        }
        
        // Get user ID from ID token
        const idToken = session.getIdToken();
        const userId = idToken.payload.sub;
        callback(userId);
    });
}

async function startChallenge(challenge) {
    // Check if user already has an active session
    if (activeSession) {
        showMessage('You already have an active container session', 'error');
        return;
    }
    
    // Get user ID properly
    getUserId(async (userId) => {
        if (!userId) {
            showMessage('Please login first', 'error');
            return;
        }
        
        currentUserId = userId;
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
                showMessage(data.error || 'Failed to launch container', 'error');
            }
        } catch (error) {
            showMessage('Error launching container: ' + error.message, 'error');
        }
    });
}

// Update showDashboard to store user info properly
function showDashboard(user) {
    currentUser = user;
    
    // Get user attributes including ID
    user.getSession((err, session) => {
        if (!err && session.isValid()) {
            const idToken = session.getIdToken();
            currentUserId = idToken.payload.sub;
            const email = idToken.payload.email || idToken.payload['cognito:username'];
            
            document.getElementById('userName').textContent = email;
            userEmail = email;
            
            console.log('User logged in:', { userId: currentUserId, email: email });
        }
    });

    document.getElementById('authSection').style.display = 'none';
    document.getElementById('dashboardSection').classList.add('active');
    document.getElementById('userNav').style.display = 'block';
    
    loadDashboardData();
}

// Also update the createChallengeCard function
function createChallengeCard(challenge) {
    const card = document.createElement('div');
    card.className = 'challenge-card';
    
    // Ensure challenge has an id
    const challengeId = challenge.id || challenge.challengeId;
    
    // Check if completed (mock for now)
    const isCompleted = false; // We'll implement progress tracking later
    const isLocked = challenge.level > 0 && challenge.prerequisites && challenge.prerequisites.length > 0;
    
    if (isCompleted) card.classList.add('completed');
    if (isLocked) card.classList.add('locked');
    
    card.innerHTML = `
        <div class="challenge-header">
            <span class="challenge-level">Level ${challenge.level || 0}</span>
            <span class="challenge-points">${isCompleted ? '✓' : ''} ${challenge.points || 0} pts</span>
        </div>
        <h3 class="challenge-title">${challenge.name}</h3>
        <p class="challenge-description">${challenge.description}</p>
        <span class="difficulty-badge difficulty-${challenge.difficulty || 'beginner'}">${challenge.difficulty || 'beginner'}</span>
        ${isLocked ? '<div style="margin-top: 1rem; color: #888;">🔒 Complete prerequisites first</div>' : ''}
        ${!isLocked && !isCompleted ? '<button class="btn" style="margin-top: 1rem; width: 100%;">Start Challenge</button>' : ''}
    `;
    
    if (!isLocked && !isCompleted) {
        card.querySelector('button').onclick = () => {
            // Pass the full challenge object with ID
            startChallenge({
                ...challenge,
                id: challengeId
            });
        };
    }
    
    return card;
}
