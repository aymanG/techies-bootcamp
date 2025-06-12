#!/bin/bash
# Fix User Pool and Configuration Script

# Load existing configuration
source step6-config.sh 2>/dev/null || source step5-config.sh 2>/dev/null || {
    echo "❌ No configuration file found. Please run previous steps first."
    exit 1
}

echo "🔧 Fixing DevOps Bootcamp User Pool and Configuration..."

# 1. Recreate the User Pool
echo "📋 Step 1: Creating new User Pool..."

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

if [ $? -eq 0 ]; then
    NEW_USER_POOL_ID=$(echo $USER_POOL_OUTPUT | jq -r '.UserPool.Id')
    echo "✅ User Pool created: $NEW_USER_POOL_ID"
else
    echo "❌ Failed to create User Pool"
    exit 1
fi

# 2. Create App Client for the new User Pool
echo "📋 Step 2: Creating App Client..."

CLIENT_OUTPUT=$(aws cognito-idp create-user-pool-client \
  --user-pool-id $NEW_USER_POOL_ID \
  --client-name "devops-bootcamp-web-client" \
  --explicit-auth-flows \
    "ALLOW_USER_PASSWORD_AUTH" \
    "ALLOW_REFRESH_TOKEN_AUTH" \
  --supported-identity-providers "COGNITO" \
  --prevent-user-existence-errors "ENABLED" \
  --output json)

if [ $? -eq 0 ]; then
    NEW_CLIENT_ID=$(echo $CLIENT_OUTPUT | jq -r '.UserPoolClient.ClientId')
    echo "✅ App Client created: $NEW_CLIENT_ID"
else
    echo "❌ Failed to create App Client"
    exit 1
fi

# 3. Update Lambda environment variables
echo "📋 Step 3: Updating Lambda environment variables..."

aws lambda update-function-configuration \
  --function-name $LAMBDA_FUNCTION_NAME \
  --environment Variables="{
    USERS_TABLE=$USERS_TABLE,
    CHALLENGES_TABLE=$CHALLENGES_TABLE,
    PROGRESS_TABLE=$PROGRESS_TABLE,
    SESSIONS_TABLE=$SESSIONS_TABLE,
    USER_POOL_ID=$NEW_USER_POOL_ID
  }" \
  --output json > /dev/null

if [ $? -eq 0 ]; then
    echo "✅ Lambda environment updated"
else
    echo "❌ Failed to update Lambda environment"
fi

# 4. Update the dashboard HTML with new configuration
echo "📋 Step 4: Updating dashboard configuration..."

# Download current dashboard
aws s3 cp s3://$BUCKET_NAME/dashboard.html dashboard-temp.html 2>/dev/null

if [ -f dashboard-temp.html ]; then
    # Update the configuration in the dashboard
    sed -i "s/USER_POOL_ID = '[^']*'/USER_POOL_ID = '$NEW_USER_POOL_ID'/g" dashboard-temp.html
    sed -i "s/CLIENT_ID = '[^']*'/CLIENT_ID = '$NEW_CLIENT_ID'/g" dashboard-temp.html
    
    # Upload back to S3
    aws s3 cp dashboard-temp.html s3://$BUCKET_NAME/dashboard.html
    aws s3 cp dashboard-temp.html s3://$BUCKET_NAME/index.html
    
    # Clean up
    rm dashboard-temp.html
    
    echo "✅ Dashboard configuration updated"
else
    echo "⚠️  Could not download dashboard.html - will create new one"
fi

# 5. Create updated configuration file
echo "📋 Step 5: Saving new configuration..."

cat > step6-config-fixed.sh << EOF
# Fixed DevOps Bootcamp Configuration
export BUCKET_NAME=$BUCKET_NAME
export WEBSITE_URL=$WEBSITE_URL
export REGION=$REGION
export DISTRIBUTION_ID=$DISTRIBUTION_ID
export CLOUDFRONT_DOMAIN=$CLOUDFRONT_DOMAIN
export CLOUDFRONT_URL=$CLOUDFRONT_URL

# NEW COGNITO CONFIGURATION
export USER_POOL_ID=$NEW_USER_POOL_ID
export CLIENT_ID=$NEW_CLIENT_ID
export PUBLIC_CLIENT_ID=$NEW_CLIENT_ID
export COGNITO_DOMAIN=https://cognito-idp.$REGION.amazonaws.com

# API CONFIGURATION  
export API_ID=$API_ID
export API_ENDPOINT=$API_ENDPOINT
export DASHBOARD_URL=$CLOUDFRONT_URL/dashboard.html

# LAMBDA CONFIGURATION
export LAMBDA_FUNCTION_NAME=$LAMBDA_FUNCTION_NAME
export LAMBDA_ARN=$LAMBDA_ARN
export LAMBDA_ROLE_NAME=$LAMBDA_ROLE_NAME

# DYNAMODB CONFIGURATION
export USERS_TABLE=$USERS_TABLE
export CHALLENGES_TABLE=$CHALLENGES_TABLE
export PROGRESS_TABLE=$PROGRESS_TABLE
export SESSIONS_TABLE=$SESSIONS_TABLE

# CONTAINER CONFIGURATION (if exists)
export ECR_REPO_URI=${ECR_REPO_URI:-}
export CLUSTER_NAME=${CLUSTER_NAME:-}
export CONTAINER_LAMBDA_ARN=${CONTAINER_LAMBDA_ARN:-}
EOF

echo "✅ Configuration saved to step6-config-fixed.sh"

# 6. Invalidate CloudFront cache
echo "📋 Step 6: Invalidating CloudFront cache..."

aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*" \
  --output json > /dev/null

echo "✅ CloudFront cache invalidated"

# 7. Test the fixes
echo "📋 Step 7: Testing the fixes..."

# Test API health
echo -n "Testing API health... "
HEALTH_RESPONSE=$(curl -s "$API_ENDPOINT/api/health" 2>/dev/null)
if echo $HEALTH_RESPONSE | grep -q "healthy"; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    echo "Response: $HEALTH_RESPONSE"
fi

# Test challenges endpoint
echo -n "Testing challenges endpoint... "
CHALLENGES_RESPONSE=$(curl -s "$API_ENDPOINT/api/challenges" 2>/dev/null)
if echo $CHALLENGES_RESPONSE | grep -q "challenges"; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    echo "Response: $CHALLENGES_RESPONSE"
fi

# 8. Create a simple auth test page
echo "📋 Step 8: Creating updated auth test page..."

cat > auth-test-fixed.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DevOps Academy - Auth Test</title>
    <style>
        body {
            margin: 0;
            padding: 20px;
            background-color: #0a0a0a;
            color: #00ff88;
            font-family: 'Courier New', monospace;
        }
        .container {
            max-width: 500px;
            margin: 0 auto;
        }
        .auth-box {
            background: #1a1a1a;
            padding: 2rem;
            border-radius: 15px;
            border: 2px solid #333;
            margin: 2rem 0;
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
        }
        button {
            width: 100%;
            padding: 1rem;
            background: #00ff88;
            color: #0a0a0a;
            border: none;
            border-radius: 8px;
            font-weight: bold;
            cursor: pointer;
            margin: 0.5rem 0;
        }
        .message {
            padding: 1rem;
            border-radius: 5px;
            margin: 1rem 0;
        }
        .success { background: #1a3a1a; border: 1px solid #00ff88; }
        .error { background: #3a1a1a; border: 1px solid #ff0088; color: #ff0088; }
        .config {
            background: #0a0a0a;
            padding: 1rem;
            border-radius: 5px;
            font-size: 0.9rem;
            margin: 1rem 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>DevOps Academy - Auth Test</h1>
        
        <div class="config">
            <h3>Configuration:</h3>
            <p>User Pool ID: $NEW_USER_POOL_ID</p>
            <p>Client ID: $NEW_CLIENT_ID</p>
            <p>API Endpoint: $API_ENDPOINT</p>
        </div>

        <div class="auth-box">
            <h2>Register New Account</h2>
            <input type="email" id="registerEmail" placeholder="Email" required>
            <input type="password" id="registerPassword" placeholder="Password (8+ chars)" required>
            <button onclick="register()">Register</button>
        </div>

        <div class="auth-box">
            <h2>Verify Email</h2>
            <input type="text" id="verifyCode" placeholder="6-digit code from email" maxlength="6">
            <button onclick="verify()">Verify</button>
        </div>

        <div class="auth-box">
            <h2>Login</h2>
            <input type="email" id="loginEmail" placeholder="Email">
            <input type="password" id="loginPassword" placeholder="Password">
            <button onclick="login()">Login</button>
        </div>

        <div id="message"></div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/amazon-cognito-identity-js@6/dist/amazon-cognito-identity.min.js"></script>
    <script>
        const poolData = {
            UserPoolId: '$NEW_USER_POOL_ID',
            ClientId: '$NEW_CLIENT_ID'
        };
        const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);
        let cognitoUser = null;
        let userEmail = '';

        function showMessage(text, type) {
            const messageEl = document.getElementById('message');
            messageEl.innerHTML = '<div class="message ' + type + '">' + text + '</div>';
        }

        function register() {
            const email = document.getElementById('registerEmail').value;
            const password = document.getElementById('registerPassword').value;
            
            if (!email || !password) {
                showMessage('Please fill in all fields', 'error');
                return;
            }

            const attributeList = [
                new AmazonCognitoIdentity.CognitoUserAttribute({
                    Name: 'email',
                    Value: email
                })
            ];

            userPool.signUp(email, password, attributeList, null, (err, result) => {
                if (err) {
                    showMessage('Registration failed: ' + err.message, 'error');
                    return;
                }
                cognitoUser = result.user;
                userEmail = email;
                showMessage('Registration successful! Check your email for verification code.', 'success');
            });
        }

        function verify() {
            const code = document.getElementById('verifyCode').value;
            
            if (!code) {
                showMessage('Please enter verification code', 'error');
                return;
            }

            if (!cognitoUser) {
                cognitoUser = new AmazonCognitoIdentity.CognitoUser({
                    Username: userEmail,
                    Pool: userPool
                });
            }

            cognitoUser.confirmRegistration(code, true, (err, result) => {
                if (err) {
                    showMessage('Verification failed: ' + err.message, 'error');
                    return;
                }
                showMessage('Email verified successfully! You can now login.', 'success');
            });
        }

        function login() {
            const email = document.getElementById('loginEmail').value;
            const password = document.getElementById('loginPassword').value;
            
            if (!email || !password) {
                showMessage('Please enter email and password', 'error');
                return;
            }

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
                    const idToken = result.getIdToken().getJwtToken();
                    showMessage('Login successful! Token: ' + idToken.substring(0, 50) + '...', 'success');
                    
                    // Test API call
                    fetch('$API_ENDPOINT/api/user/profile', {
                        headers: {
                            'Authorization': idToken
                        }
                    })
                    .then(response => response.json())
                    .then(data => {
                        showMessage('API test successful: ' + JSON.stringify(data), 'success');
                    })
                    .catch(error => {
                        showMessage('API test failed: ' + error.message, 'error');
                    });
                },
                onFailure: (err) => {
                    showMessage('Login failed: ' + err.message, 'error');
                }
            });
        }
    </script>
</body>
</html>
EOF

# Upload auth test page
aws s3 cp auth-test-fixed.html s3://$BUCKET_NAME/auth-test.html

echo "✅ Auth test page uploaded"

# 9. Final summary
echo ""
echo "🎉 FIXES COMPLETED!"
echo "===================="
echo ""
echo "✅ New User Pool ID: $NEW_USER_POOL_ID"
echo "✅ New Client ID: $NEW_CLIENT_ID"
echo "✅ Lambda environment updated"
echo "✅ Dashboard configuration updated"
echo "✅ CloudFront cache invalidated"
echo ""
echo "🔗 Test URLs:"
echo "   Dashboard: $CLOUDFRONT_URL/dashboard.html"
echo "   Auth Test: $CLOUDFRONT_URL/auth-test.html"
echo ""
echo "📋 Next steps:"
echo "   1. Wait 2-3 minutes for CloudFront cache to clear"
echo "   2. Test registration at: $CLOUDFRONT_URL/auth-test.html"
echo "   3. Test full dashboard at: $CLOUDFRONT_URL/dashboard.html"
echo ""
echo "💡 To use the new configuration:"
echo "   source step6-config-fixed.sh"
echo ""

# Clean up
rm -f auth-test-fixed.html

echo "🔧 Fix complete! Your DevOps Bootcamp should now work properly."
