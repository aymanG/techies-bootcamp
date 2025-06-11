// Add this to your dashboard for real-time analytics

async function loadAnalytics() {
    try {
        const response = await fetch(`${API_ENDPOINT}/api/leaderboard`, {
            headers: { 'Authorization': authToken }
        });
        
        if (response.ok) {
            const data = await response.json();
            displayLeaderboard(data);
        }
    } catch (error) {
        console.error('Failed to load analytics:', error);
    }
}

function displayLeaderboard(data) {
    const leaderboardHTML = `
        <div class="leaderboard-section">
            <h2 class="section-title">🏆 Global Leaderboard</h2>
            <div class="leaderboard-grid">
                ${data.global.slice(0, 10).map((user, index) => `
                    <div class="leaderboard-entry ${index < 3 ? 'top-three' : ''}">
                        <span class="rank">#${user.position}</span>
                        <span class="name">${user.displayName}</span>
                        <span class="points">${user.points} pts</span>
                        <span class="challenges">${user.completedChallenges} completed</span>
                    </div>
                `).join('')}
            </div>
        </div>
    `;
    
    document.getElementById('leaderboard-container').innerHTML = leaderboardHTML;
}

// Add real-time updates
setInterval(() => {
    if (authToken) {
        loadAnalytics();
    }
}, 30000); // Update every 30 seconds
