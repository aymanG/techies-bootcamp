#!/bin/bash
# Validation wrapper for challenges

VALIDATION_SCRIPT="/opt/validation/validate.sh"
CHALLENGE_ID="${CHALLENGE_ID:-unknown}"
USER_ID="${USER_ID:-unknown}"
SESSION_ID="${SESSION_ID:-unknown}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔍 Running validation for: $CHALLENGE_NAME${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Log validation attempt
echo "[$(date)] Validation attempt for challenge $CHALLENGE_ID by user $USER_ID" >> /var/log/challenges/validation.log

# Run the actual validation script
if [ -f "$VALIDATION_SCRIPT" ]; then
    bash "$VALIDATION_SCRIPT"
    RESULT=$?
    
    # Log result
    echo "[$(date)] Validation result: $RESULT" >> /var/log/challenges/validation.log
    
    # Show result to user
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ $RESULT -eq 0 ]; then
        echo -e "${GREEN}✅ CHALLENGE COMPLETED!${NC}"
        echo "SUCCESS:$(date):$USER_ID:$SESSION_ID" > /tmp/challenge_completed
        
        # Call webhook to update progress (if configured)
        if [ ! -z "$WEBHOOK_URL" ]; then
            curl -s -X POST "$WEBHOOK_URL" \
                -H "Content-Type: application/json" \
                -d "{\"userId\":\"$USER_ID\",\"challengeId\":\"$CHALLENGE_ID\",\"status\":\"completed\"}" \
                > /dev/null 2>&1
        fi
    else
        echo -e "${RED}❌ Not quite right. Try again!${NC}"
    fi
    
    exit $RESULT
else
    echo -e "${RED}ERROR: Validation script not found${NC}"
    exit 1
fi
