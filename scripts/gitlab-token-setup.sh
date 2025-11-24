#!/bin/bash
################################################################################
# GitLab Token Setup Script
################################################################################
# Description: Securely stores a GitLab personal access token using GPG encryption
# Usage: ./gitlab-token-setup.sh
# Requirements: gpg (GnuPG), git
# Author: Gravity Wiz
# Version: 1.1.0
################################################################################

set -euo pipefail

# Configure GPG for non-interactive use
export GPG_TTY=$(tty)
export GNUPGHOME="${GNUPGHOME:-$HOME/.gnupg}"

# Configuration
TOKEN_DIR="${HOME}/.config/gitlab-tokens"
TOKEN_FILE="${TOKEN_DIR}/token.gpg"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "ℹ $1"
}

# Check for required commands
check_requirements() {
    local missing_deps=()

    if ! command -v gpg &> /dev/null; then
        missing_deps+=("gpg")
    fi

    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_info "Install with: sudo apt-get install gnupg git"
        exit 1
    fi
}

# Initialize GPG if needed
initialize_gpg() {
    if ! gpg --list-keys &> /dev/null; then
        print_warning "No GPG keys found. You'll need to create one."
        print_info "Creating a GPG key for token encryption..."

        # Generate a basic GPG key non-interactively
        cat > /tmp/gpg-batch-$$ <<EOF
%no-protection
Key-Type: RSA
Key-Length: 2048
Name-Real: GitLab Token Storage
Name-Email: gitlab-token@localhost
Expire-Date: 0
EOF

        gpg --batch --generate-key /tmp/gpg-batch-$$
        rm -f /tmp/gpg-batch-$$
        print_success "GPG key created"
    else
        print_success "GPG is configured"
    fi
}

# Get the default GPG key
get_gpg_key() {
    gpg --list-secret-keys --keyid-format LONG | grep -A 1 "^sec" | tail -n 1 | awk '{print $1}' | head -n 1
}

# Store the token
store_token() {
    local token
    local passphrase
    local passphrase_confirm

    print_info "Please enter your GitLab Personal Access Token" >&2
    print_info "The token should have 'write_repository' scope" >&2
    echo -n "Token: " >&2
    read -s token
    echo >&2

    if [ -z "$token" ]; then
        print_error "Token cannot be empty"
        exit 1
    fi

    echo >&2
    print_info "Now create an encryption passphrase to protect your token" >&2
    print_info "You'll need this passphrase when using gitlab-push.sh" >&2
    echo -n "Encryption passphrase: " >&2
    read -s passphrase
    echo >&2

    echo -n "Confirm passphrase: " >&2
    read -s passphrase_confirm
    echo >&2

    if [ "$passphrase" != "$passphrase_confirm" ]; then
        print_error "Passphrases do not match"
        exit 1
    fi

    if [ -z "$passphrase" ]; then
        print_error "Passphrase cannot be empty"
        exit 1
    fi

    # Create directory if it doesn't exist
    mkdir -p "$TOKEN_DIR"
    chmod 700 "$TOKEN_DIR"

    # Encrypt and store the token using batch mode
    echo -n "$token" | gpg --batch --yes --symmetric --cipher-algo AES256 --armor --passphrase "$passphrase" --output "$TOKEN_FILE"

    if [ $? -eq 0 ]; then
        chmod 600 "$TOKEN_FILE"
        print_success "Token encrypted and stored at: $TOKEN_FILE" >&2
        # Output passphrase to stdout for capture
        echo "$passphrase"
    else
        print_error "Failed to encrypt token"
        exit 1
    fi
}

# Test token decryption
test_decryption() {
    local passphrase="$1"

    print_info "Testing token decryption..."

    if gpg --batch --yes --decrypt --quiet --passphrase "$passphrase" "$TOKEN_FILE" &> /dev/null; then
        print_success "Token can be decrypted successfully"
    else
        print_error "Failed to decrypt token"
        exit 1
    fi
}

# Main setup process
main() {
    echo "========================================="
    echo "  GitLab Token Setup"
    echo "========================================="
    echo

    check_requirements
    initialize_gpg

    # Check if token already exists
    if [ -f "$TOKEN_FILE" ]; then
        print_warning "A token is already stored at: $TOKEN_FILE"
        echo -n "Do you want to replace it? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_info "Setup cancelled"
            exit 0
        fi
    fi

    local passphrase
    passphrase=$(store_token)
    test_decryption "$passphrase"

    echo
    print_success "Setup complete!"
    print_info "You can now use the 'gitlab-push.sh' script to push to GitLab"
    print_info "Example: ./gitlab-push.sh origin main"
}

main "$@"
