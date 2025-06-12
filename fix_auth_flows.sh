#!/bin/bash
# Fix Cognito App Client Authentication Flows

# Load the fixed configuration
source step6-config-fixed.sh 2>/dev/null || {
    echo "❌ Please run the fix_user_pool.sh script first"
    exit 1
}

echo "🔧 Fixing Cognito App Client Authentication Flows..."

# Get current app client configuration
echo "📋 Current app client configuration:"
aws cognito-idp describe-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID \
  --query 'UserPoolClient.ExplicitAuthFlows' \
  --output table

# Update the app client to include USER_SRP_AUTH
echo "📋 Updating app client with correct authentication flows..."

UPDATE_OUTPUT=$(aws cognito-idp update-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID \
  --client-name "devops-bootcamp-web-client" \
  --explicit-auth-flows \
    "ALLOW_USER_SRP_AUTH" \
    "ALLOW_USER_PASSWORD_AUTH" \
    "ALLOW_REFRESH_TOKEN_AUTH" \
  --supported-identity-providers "COGNITO" \
  --prevent-user-existence-errors "ENABLED" \
  --output json)

if [ $? -eq 0 ]; then
    echo "✅ App client updated successfully"
    
    # Show the new configuration
    echo "📋 New app client configuration:"
    aws cognito-idp describe-user-pool-client \
      --user-pool-id $USER_POOL_ID \
      --client-id $CLIENT_ID \
      --query 'UserPoolClient.ExplicitAuthFlows' \
      --output table
else
    echo "❌ Failed to update app client"
    exit 1
fi

# Create an improved auth test page with better error handling
echo "📋 Creating improved auth test page..."

cat > auth-test-improved.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DevOps Academy - Auth Test (Fixed)</title>
    <style>
        body {
            margin: 0;
            padding: 20px;
            background-color: #0a0a0a;
            color: #00ff88;
            font-family: 'Courier New', monospace;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
        }
        .auth-box {
            background: #1a1a1a;
            padding: 2rem;
            border-radius: 15px;
            border: 2px solid #333;
            margin: 2rem 0;
            transition: border-color 0.3s;
        }
        .auth-box:hover {
            border-color: #00ff88;
        }
        input {
            width: 100%;
            padding: 0.75rem;
            margin: 0.5rem 0;
            background: #0a0a0a;
            border: 2px solid #333;
            border-radius: 8px;
            color: #00ff88;
            font-family: inherit;
            font-size: 1rem;
        }
        input:focus {
            outline: none;
            border-color: #00ff88;
            box-shadow: 0 0 10px rgba(0, 255, 136, 0.3);
        }
        button {
            width: 100%;
            padding: 1rem;
            background: linear-gradient(135deg, #00ff88, #00cc6f);
            color: #0a0a0a;
            border: none;
            border-radius: 8px;
            font-weight: bold;
            cursor: pointer;
            margin: 0.5rem 0;
            font-size: 1rem;
            transition: all 0.3s;
        }
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0, 255, 136, 0.4);
        }
        button:disabled {
            opacity: 0.5;
            cursor: not-allowed;
            transform: none;
        }
        .message {
            padding: 1rem;
            border-radius: 8px;
            margin: 1rem 0;
            white-space: pre-wrap;
            font-size: 0.9rem;
        }
        .success { 
            background: #1a3a1a; 
            border: 2px solid #00ff88; 
            color: #00ff88;
        }
        .error { 
            background: #3a1a1a; 
            border: 2px solid #ff0088; 
            color: #ff0088;
        }
        .info {
            background: #1a2a3a;
            border: 2px solid #0088ff;
            color: #0088ff;
        }
        .config {
            background: #0a0a0a;
            padding: 1rem;
            border-radius: 8px;
            font-size: 0.85rem;
            margin: 1rem 0;
            border: 1px solid #333;
        }
        .hidden {
            display: none;
        }
        .tab-buttons {
            display: flex;
            margin-bottom: 1rem;
        }
        .tab-button {
            flex: 1;
            padding: 0.75rem;
            background: #0a0a0a;
            border: 2px solid #333;
            color: #888;
            cursor: pointer;
            transition: all 0.3s;
            font-family: inherit;
        }
        .tab-button.active {
            background: #1a1a1a;
            color: #00ff88;
            border-color: #00ff88;
        }
        .tab-button:first-child {
            border-radius: 8px 0 0 8px;
        }
        .tab-button:last-child {
            border-radius: 0 8px 8px 0;
        }
        .loading {
            opacity: 0.7;
        }
        .user-info {
            background: #1a3a1a;
            border: 2px solid #00ff88;
            padding: 1.5rem;
            border-radius: 10px;
            margin: 1rem 0;
        }
        .token-display {
            background: #0a0a0a;
            padding: 1rem;
            border-radius: 5px;
            margin: 1rem 0;
            word-break: break-all;
            font-size: 0.8rem;
            max-height: 100px;
            overflow-y: auto;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 DevOps Academy - Authentication Test</h1>
        
        <div class="config">
            <h3>✅ Fixed Configuration:</h3>
            <p><strong>User Pool ID:</strong> $USER_POOL_ID</p>
            <p><strong>Client ID:</strong> $CLIENT_ID</p>
            <p><strong>API Endpoint:</strong> $API_ENDPOINT</p>
            <p><strong>Auth Flows:</strong> USER_SRP_AUTH, USER_PASSWORD_AUTH, REFRESH_TOKEN_AUTH</p>
        </div>

        <!-- Authentication Section -->
        <div id="authSection">
            <div class="auth-box">
                <div class="tab-buttons">
                    <button class="tab-button active" onclick="showTab('register')">Register</button>
                    <button class="tab-button" onclick="showTab('verify')">Verify</button>
                    <button class="tab-button" onclick="showTab('login')">Login</button>
                </div>

                <!-- Register Tab -->
                <div id="registerTab">
                    <h2>📝 Create Account</h2>
                    <input type="email" id="registerEmail" placeholder="Email address" required>
                    <input type="password" id="registerPassword" placeholder="Password (8+ chars, uppercase, lowercase, number)" required>
                    <button onclick="register()" id="registerBtn">Create Account</button>
                </div>

                <!-- Verify Tab -->
                <div id="verifyTab" class="hidden">
                    <h2>📧 Verify Email</h2>
                    <p style="color: #888; margin-bottom: 1rem;">Enter the 6-digit code sent to your email</p>
                    <input type="text" id="verifyCode" placeholder="123456" maxlength="6" style="text-align: center; font-size: 1.5rem;">
                    <button onclick="verify()" id="verifyBtn">Verify Email</button>
                </div>

                <!-- Login Tab -->
                <div id="loginTab" class="hidden">
                    <h2>🔐 Login</h2>
                    <input type="email" id="loginEmail" placeholder="Email address">
                    <input type="password" id="loginPassword" placeholder="Password">
                    <button onclick="login()" id="loginBtn">Login</button>
                </div>
            </div>
        </div>

        <!-- User Info Section (shown after login) -->
        <div id="userSection" class="hidden">
            <div class="user-info">
                <h2>🎉 Welcome to DevOps Academy!</h2>
                <p><strong>Email:</strong> <span id="userEmail"></span></p>
                <p><strong>User ID:</strong> <span id="userId"></span></p>
                <div class="token-display" id="tokenDisplay"></div>
                <button onclick="testAPI()" style="margin-top: 1rem;">Test API Call</button>
                <button onclick="logout()" style="background: #ff0088; margin-top: 0.5rem;">Logout</button>
            </div>
        </div>

        <div id="message"></div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/amazon-cognito-identity-js@6/dist/amazon-cognito-identity.min.js"></script>
    <script>
        const poolData = {
            UserPoolId: '$USER_POOL_ID',
            ClientId: '$CLIENT_ID'
        };
        const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);
        let cognitoUser = null;
        let userEmail = '';
        let currentToken = null;

        function showMessage(text, type = 'info') {
            const messageEl = document.getElementById('message');
            messageEl.innerHTML = '<div class="message ' + type + '">' + text + '</div>';
            setTimeout(() => {
                messageEl.innerHTML = '';
            }, 5000);
        }

        function showTab(tab) {
            // Update tab buttons
            document.querySelectorAll('.tab-button').forEach(btn => btn.classList.remove('active'));
            event.target.classList.add('active');

            // Update tab content
            document.getElementById('registerTab').classList.toggle('hidden', tab !== 'register');
            document.getElementById('verifyTab').classList.toggle('hidden', tab !== 'verify');
            document.getElementById('loginTab').classList.toggle('hidden', tab !== 'login');
        }

        function register() {
            const email = document.getElementById('registerEmail').value;
            const password = document.getElementById('registerPassword').value;
            const btn = document.getElementById('registerBtn');
            
            if (!email || !password) {
                showMessage('Please fill in all fields', 'error');
                return;
            }

            if (password.length < 8) {
                showMessage('Password must be at least 8 characters long', 'error');
                return;
            }

            btn.disabled = true;
            btn.textContent = 'Creating account...';
            btn.classList.add('loading');

            const attributeList = [
                new AmazonCognitoIdentity.CognitoUserAttribute({
                    Name: 'email',
                    Value: email
                })
            ];

            userPool.signUp(email, password, attributeList, null, (err, result) => {
                btn.disabled = false;
                btn.textContent = 'Create Account';
                btn.classList.remove('loading');

                if (err) {
                    showMessage('Registration failed:\\n' + err.message, 'error');
                    return;
                }

                cognitoUser = result.user;
                userEmail = email;
                showMessage('✅ Registration successful!\\nCheck your email for a verification code.', 'success');
                
                // Switch to verify tab
                showTab('verify');
                document.querySelector('.tab-button:nth-child(2)').classList.add('active');
                document.querySelector('.tab-button:nth-child(1)').classList.remove('active');
            });
        }

        function verify() {
            const code = document.getElementById('verifyCode').value;
            const btn = document.getElementById('verifyBtn');
            
            if (!code || code.length !== 6) {
                showMessage('Please enter a 6-digit verification code', 'error');
                return;
            }

            btn.disabled = true;
            btn.textContent = 'Verifying...';
            btn.classList.add('loading');

            if (!cognitoUser) {
                cognitoUser = new AmazonCognitoIdentity.CognitoUser({
                    Username: userEmail,
                    Pool: userPool
                });
            }

            cognitoUser.confirmRegistration(code, true, (err, result) => {
                btn.disabled = false;
                btn.textContent = 'Verify Email';
                btn.classList.remove('loading');

                if (err) {
                    showMessage('Verification failed:\\n' + err.message, 'error');
                    return;
                }

                showMessage('✅ Email verified successfully!\\nYou can now login with your credentials.', 'success');
                
                // Switch to login tab and pre-fill email
                showTab('login');
                document.querySelector('.tab-button:nth-child(3)').classList.add('active');
                document.querySelector('.tab-button:nth-child(2)').classList.remove('active');
                document.getElementById('loginEmail').value = userEmail;
            });
        }

        function login() {
            const email = document.getElementById('loginEmail').value;
            const password = document.getElementById('loginPassword').value;
            const btn = document.getElementById('loginBtn');
            
            if (!email || !password) {
                showMessage('Please enter email and password', 'error');
                return;
            }

            btn.disabled = true;
            btn.textContent = 'Logging in...';
            btn.classList.add('loading');

            const authenticationDetails = new AmazonCognitoIdentity.AuthenticationDetails({
                Username: email,
                Password: password
            });

            const cognitoUser = new AmazonCognitoIdentity.CognitoUser({
                Username: email,
                Pool: userPool
            });

            cognitoUser.authenticateUser(authenticationDetails, {
                onSuccess: (result) => {
                    btn.disabled = false;
                    btn.textContent = 'Login';
                    btn.classList.remove('loading');

                    const idToken = result.getIdToken().getJwtToken();
                    currentToken = idToken;
                    
                    // Decode token to get user info
                    const payload = JSON.parse(atob(idToken.split('.')[1]));
                    
                    // Show user section
                    document.getElementById('authSection').classList.add('hidden');
                    document.getElementById('userSection').classList.remove('hidden');
                    document.getElementById('userEmail').textContent = payload.email;
                    document.getElementById('userId').textContent = payload.sub;
                    document.getElementById('tokenDisplay').textContent = idToken;
                    
                    showMessage('✅ Login successful!\\nWelcome to DevOps Academy!', 'success');
                },
                onFailure: (err) => {
                    btn.disabled = false;
                    btn.textContent = 'Login';
                    btn.classList.remove('loading');

                    if (err.code === 'UserNotConfirmedException') {
                        userEmail = email;
                        showMessage('❗ Please verify your email first.\\nCheck your inbox for the verification code.', 'info');
                        showTab('verify');
                        document.querySelector('.tab-button:nth-child(2)').classList.add('active');
                        document.querySelector('.tab-button:nth-child(3)').classList.remove('active');
                    } else {
                        showMessage('Login failed:\\n' + err.message, 'error');
                    }
                }
            });
        }

        function testAPI() {
            if (!currentToken) {
                showMessage('No authentication token available', 'error');
                return;
            }

            showMessage('Testing API call...', 'info');

            fetch('$API_ENDPOINT/api/user/profile', {
                headers: {
                    'Authorization': currentToken
                }
            })
            .then(response => response.json())
            .then(data => {
                showMessage('✅ API test successful!\\nProfile data received:\\n' + JSON.stringify(data, null, 2), 'success');
            })
            .catch(error => {
                showMessage('❌ API test failed:\\n' + error.message, 'error');
            });
        }

        function logout() {
            currentUser = userPool.getCurrentUser();
            if (currentUser) {
                currentUser.signOut();
            }
            
            currentToken = null;
            document.getElementById('authSection').classList.remove('hidden');
            document.getElementById('userSection').classList.add('hidden');
            
            // Reset forms
            document.querySelectorAll('input').forEach(input => input.value = '');
            
            showMessage('✅ Logged out successfully', 'success');
        }

        // Check if already logged in
        window.onload = () => {
            const currentUser = userPool.getCurrentUser();
            if (currentUser) {
                currentUser.getSession((err, session) => {
                    if (!err && session.isValid()) {
                        const idToken = session.getIdToken().getJwtToken();
                        const payload = JSON.parse(atob(idToken.split('.')[1]));
                        
                        currentToken = idToken;
                        document.getElementById('authSection').classList.add('hidden');
                        document.getElementById('userSection').classList.remove('hidden');
                        document.getElementById('userEmail').textContent = payload.email;
                        document.getElementById('userId').textContent = payload.sub;
                        document.getElementById('tokenDisplay').textContent = idToken;
                        
                        showMessage('✅ Already logged in!', 'success');
                    }
                });
            }
        };
    </script>
</body>
</html>
EOF

# Upload the improved auth test page
aws s3 cp auth-test-improved.html s3://$BUCKET_NAME/auth-test.html

echo "✅ Improved auth test page uploaded"

# Update the main dashboard with the correct auth flows as well
echo "📋 Updating main dashboard..."

# Download, update, and re-upload dashboard
aws s3 cp s3://$BUCKET_NAME/dashboard.html dashboard-temp.html 2>/dev/null

if [ -f dashboard-temp.html ]; then
    # Ensure the dashboard has the correct User Pool and Client IDs
    sed -i "s/USER_POOL_ID = '[^']*'/USER_POOL_ID = '$USER_POOL_ID'/g" dashboard-temp.html
    sed -i "s/CLIENT_ID = '[^']*'/CLIENT_ID = '$CLIENT_ID'/g" dashboard-temp.html
    
    # Upload back
    aws s3 cp dashboard-temp.html s3://$BUCKET_NAME/dashboard.html
    aws s3 cp dashboard-temp.html s3://$BUCKET_NAME/index.html
    
    rm dashboard-temp.html
    echo "✅ Dashboard updated"
fi

# Invalidate CloudFront cache
echo "📋 Invalidating CloudFront cache..."
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*" \
  --output json > /dev/null

echo "✅ CloudFront cache invalidated"

# Clean up
rm -f auth-test-improved.html

echo ""
echo "🎉 AUTHENTICATION FLOWS FIXED!"
echo "================================"
echo ""
echo "✅ App client now supports:"
echo "   - USER_SRP_AUTH (for secure password authentication)"
echo "   - USER_PASSWORD_AUTH (for admin authentication)"  
echo "   - REFRESH_TOKEN_AUTH (for token refresh)"
echo ""
echo "🔗 Test the fix:"
echo "   1. Go to: $CLOUDFRONT_URL/auth-test.html"
echo "   2. Register a new account"
echo "   3. Verify your email"
echo "   4. Login successfully"
echo ""
echo "📋 If you still have issues:"
echo "   1. Clear your browser cache"
echo "   2. Try in incognito/private mode"
echo "   3. Check browser console for any errors"
echo ""
echo "🎯 Main dashboard: $CLOUDFRONT_URL/dashboard.html"
echo ""
