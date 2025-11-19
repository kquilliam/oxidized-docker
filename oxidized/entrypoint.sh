#!/bin/sh
set -e

echo "Authenticating to Vault and fetching secrets..."
eval $(python secrets.py)
echo "Secrets successfully loaded."

# Create .ssh directory if it doesn't exist
echo "Setting up SSH keys from Vault..."
mkdir -p /home/oxidized/.ssh

# Write private key from Vault to file
if [ ! -z "$OXIDIZED_PRIVATE_KEY" ]; then
    # Extract the base64 data between the BEGIN and END markers
    # Format it properly with the header, wrapped base64, and footer
    echo "$OXIDIZED_PRIVATE_KEY" | \
        sed 's/.*-----BEGIN OPENSSH PRIVATE KEY-----/-----BEGIN OPENSSH PRIVATE KEY-----\n/' | \
        sed 's/-----END OPENSSH PRIVATE KEY-----.*/\n-----END OPENSSH PRIVATE KEY-----/' | \
        sed '2s/\(.\{64\}\)/\1\n/g' > /home/oxidized/.ssh/id_ed25519
    chmod 600 /home/oxidized/.ssh/id_ed25519
    echo "Private key written to /home/oxidized/.ssh/id_ed25519"
else
    echo "WARNING: OXIDIZED_PRIVATE_KEY not found in Vault"
fi

# Write public key from Vault to file
if [ ! -z "$OXIDIZED_PUBLIC_KEY" ]; then
    # Public keys are typically single-line, just write as-is
    printf '%s\n' "$OXIDIZED_PUBLIC_KEY" > /home/oxidized/.ssh/id_ed25519.pub
    chmod 644 /home/oxidized/.ssh/id_ed25519.pub
    echo "Public key written to /home/oxidized/.ssh/id_ed25519.pub"
else
    echo "WARNING: OXIDIZED_PUBLIC_KEY not found in Vault"
fi

# Set up SSH known_hosts BEFORE attempting git operations
echo "Adding GitHub host key to known_hosts..."
ssh-keyscan github.com >> /home/oxidized/.ssh/known_hosts 2>/dev/null || true

# Set proper ownership and permissions on .ssh directory
chown -R oxidized:oxidized /home/oxidized/.ssh
chmod 700 /home/oxidized/.ssh
chmod 600 /home/oxidized/.ssh/id_ed25519 2>/dev/null || true
chmod 644 /home/oxidized/.ssh/id_ed25519.pub 2>/dev/null || true
chmod 644 /home/oxidized/.ssh/known_hosts 2>/dev/null || true

# --- Git Repository Initialization with Remote Recovery ---
GIT_REPO_PATH="/home/oxidized/.config/oxidized/configs.git"

# Check if repository exists
if [ ! -d "${GIT_REPO_PATH}/.git" ]; then
    echo "Git repository not found at ${GIT_REPO_PATH}"
    
    # Try to restore from remote if configured
    if [ ! -z "$GIT_REMOTE_REPO" ]; then
        echo "Attempting to restore repository from remote: ${GIT_REMOTE_REPO}"
        
        # Create parent directory and set ownership to oxidized user
        mkdir -p "$(dirname "$GIT_REPO_PATH")"
        chown -R oxidized:oxidized "$(dirname "$GIT_REPO_PATH")"
        
        # Clone the remote repository as the oxidized user (who owns the SSH keys)
        echo "Cloning repository as oxidized user..."
        if su - oxidized -c "git clone '$GIT_REMOTE_REPO' '$GIT_REPO_PATH'" 2>&1; then
            echo "Successfully cloned repository from remote!"
            cd "$GIT_REPO_PATH"
            git config user.name "oxidized"
            git config user.email "oxidized@example.com"
            chown -R oxidized:oxidized "$GIT_REPO_PATH"
        else
            echo "Failed to clone from remote (see error above). Initializing new repository..."
            mkdir -p "$GIT_REPO_PATH"
            cd "$GIT_REPO_PATH"
            git init
            git config user.name "oxidized"
            git config user.email "oxidized@example.com"
            git remote add origin "$GIT_REMOTE_REPO" || true
            chown -R oxidized:oxidized "$GIT_REPO_PATH"
        fi
    else
        echo "No remote repository configured. Initializing new local repository..."
        mkdir -p "$GIT_REPO_PATH"
        cd "$GIT_REPO_PATH"
        git init
        git config user.name "oxidized"
        git config user.email "oxidized@example.com"
    fi
    
    # Set permissions on the repository
    echo "Setting permissions on repository..."
    chown -R oxidized:oxidized "$GIT_REPO_PATH"
else
    echo "Existing Git repository found at ${GIT_REPO_PATH}"
    
    # Verify repository integrity and sync with remote if needed
    cd "$GIT_REPO_PATH"
    if [ ! -z "$GIT_REMOTE_REPO" ]; then
        echo "Verifying remote configuration..."
        CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
        
        if [ -z "$CURRENT_REMOTE" ]; then
            echo "Adding remote origin: ${GIT_REMOTE_REPO}"
            git remote add origin "$GIT_REMOTE_REPO" || true
        elif [ "$CURRENT_REMOTE" != "$GIT_REMOTE_REPO" ]; then
            echo "Updating remote origin from ${CURRENT_REMOTE} to ${GIT_REMOTE_REPO}"
            git remote set-url origin "$GIT_REMOTE_REPO" || true
        fi
        
        # Optional: Fetch latest from remote (uncomment if needed)
        # echo "Fetching latest from remote..."
        # git fetch origin || echo "Warning: Failed to fetch from remote"
    fi
fi
# --- End of Git repository logic ---

# Define file paths
TEMPLATE_FILE="/home/oxidized/.config/oxidized/config.template"
CONFIG_FILE="/home/oxidized/.config/oxidized/config"

# Substitute placeholders with environment variables
sed -e "s/__NETBOX_TOKEN__/${NETBOX_TOKEN}/g" \
    -e "s/__NETWORK_USERNAME__/${NETWORK_USERNAME_RW}/g" \
    -e "s/__NETWORK_PASSWORD__/${NETWORK_PASSWORD_RW}/g" \
    -e "s/__PAN_API_USER_RO__/${PAN_API_USER_RO}/g" \
    -e "s/__PAN_API_PASS_RO__/${PAN_API_PASS_RO}/g" \
    "$TEMPLATE_FILE" > "$CONFIG_FILE"

# Ensure the config file is owned by oxidized
chown oxidized:oxidized "$CONFIG_FILE"

# Drop privileges and execute the main container command as oxidized user
echo "Starting Oxidized as oxidized user..."
exec gosu oxidized "$@"
