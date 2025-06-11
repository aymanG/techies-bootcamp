FROM devops-bootcamp-base:latest

# Set challenge info
ENV CHALLENGE_NAME="Welcome to DevOps Academy"
ENV CHALLENGE_ID="welcome-01"

# Create challenge files
USER root
RUN mkdir -p /home/student/challenge && \
    cat > /home/student/challenge/README.txt << 'EOM'
🎯 Welcome to your first DevOps challenge!

Your mission:
1. Find the hidden flag file somewhere in your home directory
2. Read the contents of the flag file  
3. Run 'validate' when you think you've completed the challenge

💡 Hints:
- Use 'ls -la' to see hidden files
- Hidden files start with a dot (.)
- The 'find' command can help locate files
- Try: find ~ -name "*flag*" -type f

Good luck!
EOM

# Create the hidden flag
RUN echo "FLAG{WELCOME_TO_DEVOPS_ACADEMY_$(date +%Y)}" > /home/student/.secret_flag && \
    chmod 644 /home/student/.secret_flag && \
    chown student:student /home/student/.secret_flag && \
    chown -R student:student /home/student/challenge

# Create validation script
RUN cat > /opt/validation/validate.sh << 'EOM'
#!/bin/bash

FLAG_FILE="/home/student/.secret_flag"
FOUND_FILE="/home/student/.found_flag"
HISTORY_FILE="/home/student/.bash_history"

# Check if flag was already found
if [ -f "$FOUND_FILE" ]; then
    echo "✅ You've already completed this challenge!"
    exit 0
fi

# Check if user read the flag (multiple methods)
if [ -f "$HISTORY_FILE" ]; then
    # Check if they used cat, less, more, or any command to view the flag
    if grep -E "(cat|less|more|tail|head|grep).*\.secret_flag" "$HISTORY_FILE" > /dev/null 2>&1; then
        touch "$FOUND_FILE"
        echo "✅ Congratulations! You found and read the secret flag!"
        echo "🎉 You've completed your first challenge!"
        exit 0
    fi
fi

# Also check if they know the flag content (maybe they used a different method)
echo "❓ Did you find the flag? What does it say?"
echo "   Hint: It starts with FLAG{WELCOME..."
exit 1
EOM

RUN chmod +x /opt/validation/validate.sh

# Add detailed instructions
RUN cat > /opt/challenges/instructions.txt << 'EOM'
🚀 Your First Challenge: Find the Hidden Flag
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📝 Objectives:
   • Learn basic Linux navigation commands
   • Find hidden files in the filesystem
   • Read file contents

🛠️  Useful Commands:
   • pwd          - Print working directory (where am I?)
   • ls           - List files
   • ls -la       - List ALL files (including hidden)
   • cd           - Change directory
   • cat [file]   - Display file contents
   • find         - Search for files

💡 Pro Tips:
   • Hidden files in Linux start with a dot (.)
   • Your home directory is /home/student or just ~
   • Use Tab key for auto-completion
   • Type 'validate' when you're ready!

🎯 Success Criteria:
   Find and read the hidden flag file in your home directory

Good luck, future DevOps engineer! 🚀
EOM

EXPOSE 22 3000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/services.conf"]
