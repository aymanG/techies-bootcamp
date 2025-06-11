FROM rockylinux:9

# Install essential packages
RUN dnf update -y && \
    dnf install -y epel-release && \
    dnf install -y --allowerasing \
    openssh-server \
    openssh-clients \
    sudo \
    vim \
    nano \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    bash-completion \
    tree \
    procps-ng \
    nc \
    net-tools \
    bind-utils \
    tar \
    gzip \
    unzip \
    which \
    passwd \
    cronie \
    supervisor \
    make \
    gcc-c++ \
    python3-devel && \
    dnf clean all

# Install Node.js for WeTTY
RUN curl -fsSL https://rpm.nodesource.com/setup_18.x | bash - && \
    dnf install -y nodejs && \
    dnf clean all

# Install WeTTY globally
RUN npm install -g wetty

# Configure SSH
RUN ssh-keygen -A && \
    sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Create student user
RUN useradd -m -s /bin/bash student && \
    echo "student:devops123" | chpasswd && \
    usermod -aG wheel student && \
    echo '%wheel ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Create necessary directories
RUN mkdir -p /opt/validation /opt/challenges /var/log/challenges /etc/supervisor/conf.d

# Add validation wrapper script
COPY validation-wrapper.sh /opt/validation/wrapper.sh
RUN chmod +x /opt/validation/wrapper.sh

# Create supervisor configuration for SSH and WeTTY
RUN cat > /etc/supervisor/conf.d/services.conf << 'EOL'
[supervisord]
nodaemon=true
user=root

[program:sshd]
command=/usr/sbin/sshd -D
autostart=true
autorestart=true
stdout_logfile=/var/log/sshd.log
stderr_logfile=/var/log/sshd_error.log

[program:wetty]
command=/usr/bin/node /usr/lib/node_modules/wetty/dist/cli.js --host 0.0.0.0 --port 3000 --ssh-host=localhost --ssh-port=22 --ssh-user=student --title "DevOps Bootcamp Terminal"
autostart=true
autorestart=true
stdout_logfile=/var/log/wetty.log
stderr_logfile=/var/log/wetty_error.log
environment=NODE_ENV="production"
EOL

# Create welcome script
RUN cat > /etc/profile.d/welcome.sh << 'EOL'
#!/bin/bash
if [ "$USER" = "student" ] && [ -z "$WELCOMED" ]; then
    export WELCOMED=1
    clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              Welcome to DevOps Bootcamp!                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📋 Challenge: $CHALLENGE_NAME"
    echo "🆔 ID: $CHALLENGE_ID"
    echo ""
    if [ -f /opt/challenges/instructions.txt ]; then
        cat /opt/challenges/instructions.txt
        echo ""
    fi
    echo "💡 Type 'validate' to check your progress"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
fi
EOL

RUN chmod +x /etc/profile.d/welcome.sh

# Create validate alias for easier access
RUN echo "alias validate='sudo /opt/validation/wrapper.sh'" >> /home/student/.bashrc

# Set environment variables
ENV CHALLENGE_NAME="Base Challenge"
ENV CHALLENGE_ID="base"

# Expose necessary ports
EXPOSE 22 3000

# Start both services using supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/services.conf"]

