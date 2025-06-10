# Phase 1 - Step 3: Cognito User Authentication

## Goal
Add user registration, email verification, and login using AWS Cognito

## Prerequisites
- Step 2 completed (CloudFront working)
- `step2-config.sh` file with your configuration

## Step 3.1: Load Previous Configuration

```bash
# Load your previous configuration
source step2-config.sh
echo "Using CloudFront: $CLOUDFRONT_URL"
```

## Step 3.2: Create Cognito User Pool

```bash
# Create Cognito User Pool with email verification
USER_POOL_OUTPUT=$(aws cognito-idp create-user-pool \
  --pool-name "devops-bootcamp-users" \
  --policies '{
    "PasswordPolicy": {
      "MinimumLength": 8,
      "RequireUppercase": true,
      "RequireLowercase": true,
      "RequireNumbers": true,
      "RequireSymbols": false
    }
  }' \
  --auto-verified-attributes "email" \
  --username-attributes "email" \
  --mfa-configuration "OFF" \
  --email-configuration '{
    "EmailSendingAccount": "COGNITO_DEFAULT"
  }' \
  --email-verification-message "Your DevOps Bootcamp verification code is {####}" \
  --email-verification-subject "Verify your DevOps Bootcamp account" \
  --user-attribute-update-settings '{
    "AttributesRequireVerificationBeforeUpdate": ["email"]
  }' \
  --output json)

# Extract User Pool ID
USER_POOL_ID=$(echo $USER_POOL_OUTPUT | jq -r '.UserPool.Id')
echo "User Pool ID: $USER_POOL_ID"

# Save to config
echo "export USER_POOL_ID=$USER_POOL_ID" >> step2-config.sh
```

## Step 3.3: Create App Client

```bash
# Create app client for web authentication
CLIENT_OUTPUT=$(aws cognito-idp create-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-name "devops-bootcamp-web-client" \
  --generate-secret \
  --explicit-auth-flows \
    "ALLOW_USER_PASSWORD_AUTH" \
    "ALLOW_REFRESH_TOKEN_AUTH" \
  --supported-identity-providers "COGNITO" \
  --allowed-o-auth-flows "code" \
  --allowed-o-auth-scopes "email" "openid" "profile" \
  --callback-urls "https://$CLOUDFRONT_DOMAIN/callback.html" \
  --logout-urls "https://$CLOUDFRONT_DOMAIN/" \
  --output json)

# Extract Client ID
CLIENT_ID=$(echo $CLIENT_OUTPUT | jq -r '.UserPoolClient.ClientId')
CLIENT_SECRET=$(echo $CLIENT_OUTPUT | jq -r '.UserPoolClient.ClientSecret')
echo "Client ID: $CLIENT_ID"

# Save to config
echo "export CLIENT_ID=$CLIENT_ID" >> step2-config.sh
echo "export CLIENT_SECRET=$CLIENT_SECRET" >> step2-config.sh
```

## Step 3.4: Get Cognito Domain

```bash
# Get the Cognito domain for your region
REGION=$(aws configure get region)
COGNITO_DOMAIN="https://cognito-idp.$REGION.amazonaws.com"
echo "Cognito Domain: $COGNITO_DOMAIN"

# Save to config
echo "export COGNITO_DOMAIN=$COGNITO_DOMAIN" >> step2-config.sh
echo "export REGION=$REGION" >> step2-config.sh
```

## Step 3.5: Create Authentication Test Page

Create `auth-test.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DevOps Bootcamp - Authentication</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background-color: #0a0a0a;
            color: #00ff88;
            font-family: 'Courier New', monospace;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        .container {
            text-align: center;
            padding: 20px;
            max-width: 400px;
            width: 100%;
        }
        h1 {
            font-size: 2.5rem;
            margin-bottom: 2rem;
            text-shadow: 0 0 20px rgba(0, 255, 136, 0.5);
        }
        .auth-form {
            background: #1a1a1a;
            padding: 30px;
            border-radius: 10px;
            border: 2px solid #333;
        }
        input {
            width: 100%;
            padding: 12px;
            margin: 10px 0;
            background: #0a0a0a;
            border: 1px solid #333;
            color: #00ff88;
            border-radius: 5px;
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
            padding: 12px;
            margin: 10px 0;
            background: #00ff88;
            color: #0a0a0a;
            border: none;
            border-radius: 5px;
            font-weight: bold;
            cursor: pointer;
            font-size: 1rem;
            transition: all 0.3s;
        }
        button:hover {
            background: #00cc6f;
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0, 255, 136, 0.4);
        }
        button:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }
        .tab-buttons {
            display: flex;
            margin-bottom: 20px;
        }
        .tab-button {
            flex: 1;
            padding: 10px;
            background: #0a0a0a;
            border: 1px solid #333;
            color: #888;
            cursor: pointer;
            transition: all 0.3s;
        }
        .tab-button.active {
            background: #1a1a1a;
            color: #00ff88;
            border-color: #00ff88;
        }
        .tab-button:first-child {
            border-radius: 5px 0 0 5px;
        }
        .tab-button:last-child {
            border-radius: 0 5px 5px 0;
        }
        .message {
            margin: 20px 0;
            padding: 15px;
            border-radius: 5px;
            font-size: 0.9rem;
        }
        .success {
            background: #1a3a1a;
            border: 1px solid #00ff88;
            color: #00ff88;
        }
        .error {
            background: #3a1a1a;
            border: 1px solid #ff0088;
            color: #ff0088;
        }
        .info {
            background: #1a2a3a;
            border: 1px solid #0088ff;
            color: #0088ff;
        }
        .hidden {
            display: none;
        }
        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #333;
            border-top-color: #00ff88;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        .user-info {
            background: #1a1a1a;
            padding: 20px;
            border-radius: 10px;
            border: 2px solid #00ff88;
            margin-top: 20px;
        }
        .logout-button {
            background: #ff0088;
            margin-top: 20px;
        }
        .logout-button:hover {
            background: #cc0066;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>DevOps Bootcamp</h1>
        
        <!-- Not Logged In View -->
        <div id="auth-section" class="auth-form">
            <div class="tab-buttons">
                <div class="tab-button active" onclick="showTab('login')">Login</div>
                <div class="tab-button" onclick="showTab('register')">Register</div>
            </div>
            
            <!-- Login Form -->
            <div id="login-form">
                <h2>Welcome Back</h2>
                <input type="email" id="login-email" placeholder="Email" autocomplete="email">
                <input type="password" id="login-password" placeholder="Password" autocomplete="current-password">
                <button onclick="login()" id="login-button">Login</button>
            </div>
            
            <!-- Register Form -->
            <div id="register-form" class="hidden">
                <h2>Create Account</h2>
                <input type="email" id="register-email" placeholder="Email" autocomplete="email">
                <input type="password" id="register-password" placeholder="Password (8+ chars, uppercase, lowercase, number)" autocomplete="new-password">
                <input type="password" id="register-confirm" placeholder="Confirm Password" autocomplete="new-password">
                <button onclick="register()" id="register-button">Register</button>
            </div>
            
            <!-- Verify Form -->
            <div id="verify-form" class="hidden">
                <h2>Verify Email</h2>
                <p style="color: #888; font-size: 0.9rem;">Check your email for a verification code</p>
                <input type="text" id="verification-code" placeholder="Enter 6-digit code" maxlength="6">
                <button onclick="verify()" id="verify-button">Verify</button>
            </div>
        </div>
        
        <!-- Logged In View -->
        <div id="user-section" class="hidden">
            <div class="user-info">
                <h2>Welcome to DevOps Bootcamp!</h2>
                <p>Email: <span id="user-email"></span></p>
                <p>User ID: <span id="user-id"></span></p>
                <p class="success">✅ Authentication is working!</p>
                <button class="logout-button" onclick="logout()">Logout</button>
            </div>
            
            <div style="margin-top: 30px; padding: 20px; background: #1a1a1a; border-radius: 10px;">
                <h3>Next Steps:</h3>
                <p style="color: #888;">Step 4: Create Lambda Functions</p>
                <p style="color: #888;">Step 5: Build API Gateway</p>
                <p style="color: #888;">Step 6: Connect Frontend to Backend</p>
            </div>
        </div>
        
        <!-- Messages -->
        <div id="message" class="hidden"></div>
    </div>

    <!-- AWS SDK -->
    <script src="https://cdn.jsdelivr.net/npm/amazon-cognito-identity-js@6/dist/amazon-cognito-identity.min.js"></script>
    
    <script>
        // Configuration - REPLACE THESE WITH YOUR VALUES
        const poolData = {
            UserPoolId: 'YOUR_USER_POOL_ID',
            ClientId: 'YOUR_CLIENT_ID'
        };
        
        // Initialize Cognito
        const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);
        let cognitoUser = null;
        let userEmail = '';
        
        // Check if user is already logged in
        checkAuth();
        
        function checkAuth() {
            const currentUser = userPool.getCurrentUser();
            if (currentUser) {
                currentUser.getSession((err, session) => {
                    if (err) {
                        showAuthSection();
                    } else if (session.isValid()) {
                        showUserSection(currentUser);
                    } else {
                        showAuthSection();
                    }
                });
            } else {
                showAuthSection();
            }
        }
        
        function showTab(tab) {
            document.querySelectorAll('.tab-button').forEach(btn => btn.classList.remove('active'));
            document.querySelector(`.tab-button:${tab === 'login' ? 'first' : 'last'}-child`).classList.add('active');
            
            document.getElementById('login-form').classList.toggle('hidden', tab !== 'login');
            document.getElementById('register-form').classList.toggle('hidden', tab !== 'register');
            document.getElementById('verify-form').classList.add('hidden');
            hideMessage();
        }
        
        function showMessage(text, type) {
            const messageEl = document.getElementById('message');
            messageEl.textContent = text;
            messageEl.className = `message ${type}`;
        }
        
        function hideMessage() {
            document.getElementById('message').className = 'hidden';
        }
        
        function showAuthSection() {
            document.getElementById('auth-section').classList.remove('hidden');
            document.getElementById('user-section').classList.add('hidden');
        }
        
        function showUserSection(user) {
            document.getElementById('auth-section').classList.add('hidden');
            document.getElementById('user-section').classList.remove('hidden');
            
            user.getUserAttributes((err, attributes) => {
                if (!err) {
                    const email = attributes.find(attr => attr.Name === 'email')?.Value;
                    const sub = attributes.find(attr => attr.Name === 'sub')?.Value;
                    document.getElementById('user-email').textContent = email || 'Unknown';
                    document.getElementById('user-id').textContent = sub || 'Unknown';
                }
            });
        }
        
        async function register() {
            const email = document.getElementById('register-email').value;
            const password = document.getElementById('register-password').value;
            const confirm = document.getElementById('register-confirm').value;
            
            if (!email || !password) {
                showMessage('Please fill in all fields', 'error');
                return;
            }
            
            if (password !== confirm) {
                showMessage('Passwords do not match', 'error');
                return;
            }
            
            if (password.length < 8) {
                showMessage('Password must be at least 8 characters', 'error');
                return;
            }
            
            const button = document.getElementById('register-button');
            button.disabled = true;
            button.innerHTML = '<span class="loading"></span>';
            
            const attributeList = [
                new AmazonCognitoIdentity.CognitoUserAttribute({
                    Name: 'email',
                    Value: email
                })
            ];
            
            userPool.signUp(email, password, attributeList, null, (err, result) => {
                button.disabled = false;
                button.textContent = 'Register';
                
                if (err) {
                    showMessage(err.message || 'Registration failed', 'error');
                    return;
                }
                
                cognitoUser = result.user;
                userEmail = email;
                showMessage('Success! Check your email for verification code', 'success');
                
                // Show verification form
                document.getElementById('register-form').classList.add('hidden');
                document.getElementById('verify-form').classList.remove('hidden');
            });
        }
        
        function verify() {
            const code = document.getElementById('verification-code').value;
            
            if (!code) {
                showMessage('Please enter verification code', 'error');
                return;
            }
            
            const button = document.getElementById('verify-button');
            button.disabled = true;
            button.innerHTML = '<span class="loading"></span>';
            
            if (!cognitoUser) {
                cognitoUser = new AmazonCognitoIdentity.CognitoUser({
                    Username: userEmail,
                    Pool: userPool
                });
            }
            
            cognitoUser.confirmRegistration(code, true, (err, result) => {
                button.disabled = false;
                button.textContent = 'Verify';
                
                if (err) {
                    showMessage(err.message || 'Verification failed', 'error');
                    return;
                }
                
                showMessage('Email verified! You can now login', 'success');
                setTimeout(() => {
                    showTab('login');
                }, 2000);
            });
        }
        
        function login() {
            const email = document.getElementById('login-email').value;
            const password = document.getElementById('login-password').value;
            
            if (!email || !password) {
                showMessage('Please enter email and password', 'error');
                return;
            }
            
            const button = document.getElementById('login-button');
            button.disabled = true;
            button.innerHTML = '<span class="loading"></span>';
            
            const authenticationDetails = new AmazonCognitoIdentity.AuthenticationDetails({
                Username: email,
                Password: password
            });
            
            cognitoUser = new AmazonCognitoIdentity.CognitoUser({
                Username: email,
                Pool: userPool
            });
            
            cognitoUser.authenticateUser(authenticationDetails, {
                onSuccess: (result) => {
                    button.disabled = false;
                    button.textContent = 'Login';
                    showMessage('Login successful!', 'success');
                    showUserSection(cognitoUser);
                },
                onFailure: (err) => {
                    button.disabled = false;
                    button.textContent = 'Login';
                    
                    if (err.code === 'UserNotConfirmedException') {
                        userEmail = email;
                        showMessage('Please verify your email first', 'info');
                        document.getElementById('login-form').classList.add('hidden');
                        document.getElementById('verify-form').classList.remove('hidden');
                    } else {
                        showMessage(err.message || 'Login failed', 'error');
                    }
                }
            });
        }
        
        function logout() {
            const currentUser = userPool.getCurrentUser();
            if (currentUser) {
                currentUser.signOut();
            }
            showAuthSection();
            showMessage('Logged out successfully', 'info');
        }
    </script>
</body>
</html>
```

Now create a configuration script `config.js`:

```javascript
// This file will be generated with your actual values
const CognitoConfig = {
    UserPoolId: 'YOUR_USER_POOL_ID',
    ClientId: 'YOUR_CLIENT_ID',
    Region: 'YOUR_REGION'
};
```

## Step 3.6: Generate Configuration File

```bash
# Generate config.js with your actual values
cat > config.js << EOF
const CognitoConfig = {
    UserPoolId: '$USER_POOL_ID',
    ClientId: '$CLIENT_ID',
    Region: '$REGION'
};
EOF

# Update auth-test.html with your configuration
sed -i "s/YOUR_USER_POOL_ID/$USER_POOL_ID/g" auth-test.html
sed -i "s/YOUR_CLIENT_ID/$CLIENT_ID/g" auth-test.html

echo "Configuration updated in auth-test.html"
```

## Step 3.7: Upload Files to S3

```bash
# Upload the authentication test page
aws s3 cp auth-test.html s3://$BUCKET_NAME/
aws s3 cp config.js s3://$BUCKET_NAME/

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*"

echo "Files uploaded. Access at: $CLOUDFRONT_URL/auth-test.html"
```

## Step 3.8: Test Authentication Flow

1. **Open the authentication page**:
   ```bash
   echo "Open in browser: $CLOUDFRONT_URL/auth-test.html"
   ```

2. **Test Registration**:
   - Click "Register" tab
   - Enter an email you have access to
   - Use password: TestPass123
   - Check email for verification code
   - Enter the 6-digit code

3. **Test Login**:
   - Use the email and password
   - Should see "Welcome to DevOps Bootcamp!"

## Validation Checklist

```bash
# 1. Check User Pool exists
aws cognito-idp describe-user-pool --user-pool-id $USER_POOL_ID \
  --query 'UserPool.Status' --output text
echo "✓ User Pool status checked"

# 2. Check App Client
aws cognito-idp describe-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID \
  --query 'UserPoolClient.ClientName' --output text
echo "✓ App Client configured"

# 3. List users (after you register)
aws cognito-idp list-users --user-pool-id $USER_POOL_ID \
  --query 'Users[].Username' --output table
echo "✓ Can list users"

# 4. Save complete configuration
cat > step3-config.sh << EOF
$(cat step2-config.sh)
export AUTH_TEST_URL=$CLOUDFRONT_URL/auth-test.html
EOF
echo "✓ Configuration saved to step3-config.sh"
```

## Cost Analysis
- Cognito: **FREE for first 50,000 monthly active users**
- After free tier: $0.0055 per MAU
- **Total for Step 3: $0**

## Security Features Enabled
1. ✅ **Email verification required**
2. ✅ **Secure password policy**
3. ✅ **HTTPS only communication**
4. ✅ **JWT tokens for sessions**
5. ✅ **No passwords stored in frontend**

## Troubleshooting

1. **If registration fails with "User already exists"**:
   ```bash
   # Delete the user and try again
   aws cognito-idp admin-delete-user \
     --user-pool-id $USER_POOL_ID \
     --username "email@example.com"
   ```

2. **If you don't receive verification email**:
   - Check spam folder
   - Verify email address is correct
   - Check AWS SES sandbox limits

3. **If login fails after verification**:
   - Ensure you're using the exact email (case-sensitive)
   - Password must match exactly

## What You've Achieved
- ✅ User registration with email
- ✅ Email verification flow
- ✅ Secure login/logout
- ✅ Session management
- ✅ All in the browser (no backend yet!)

## Next Step Preview
In Step 4, we'll:
1. Create Lambda functions
2. Add DynamoDB tables
3. Build an API Gateway
4. Connect authentication to backend

---

**Test the authentication by registering a new account!** You should receive a verification email within 1-2 minutes. Once you can login and see the welcome message, Step 3 is complete!
