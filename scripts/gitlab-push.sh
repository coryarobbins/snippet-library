#!/bin/bash
################################################################################
# GitLab Push Script with Encrypted Token
################################################################################
# Description: Pushes to GitLab using an encrypted personal access token
# Usage: ./gitlab-push.sh [remote] [branch] [additional-git-push-args]
#        ./gitlab-push.sh                    # Uses current branch and origin
#        ./gitlab-push.sh origin main        # Push main to origin
#        ./gitlab-push.sh origin feature --force  # Force push
# Requirements: gpg (GnuPG), git, gitlab-token-setup.sh (run first)
# Author: Gravity Wiz
# Version: 1.0.0
################################################################################

set -euo pipefail

# Configuration
TOKEN_DIR="${HOME}/.config/gitlab-tokens"
TOKEN_FILE="${TOKEN_DIR}/token.gpg"
MAX_RETRIES=4
INITIAL_BACKOFF=2

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not in a git repository"
        exit 1
    fi
}

# Check if token file exists
check_token_exists() {
    if [ ! -f "$TOKEN_FILE" ]; then
        print_error "Token file not found: $TOKEN_FILE"
        print_info "Please run gitlab-token-setup.sh first"
        exit 1
    fi
}

# Decrypt token
get_token() {
    local token
    token=$(gpg --decrypt --quiet "$TOKEN_FILE" 2>/dev/null)

    if [ -z "$token" ]; then
        print_error "Failed to decrypt token"
        exit 1
    fi

    echo "$token"
}

# Get current branch
get_current_branch() {
    git rev-parse --abbrev-ref HEAD
}

# Get remote URL
get_remote_url() {
    local remote="${1:-origin}"
    git remote get-url "$remote" 2>/dev/null || echo ""
}

# Parse GitLab URL and inject token
inject_token_to_url() {
    local url="$1"
    local token="$2"

    # Remove existing credentials if any
    url=$(echo "$url" | sed -E 's|https://[^@]*@|https://|')

    # Handle both HTTPS and git@ URLs
    if [[ "$url" =~ ^https:// ]]; then
        # HTTPS URL: inject token
        echo "$url" | sed "s|https://|https://oauth2:${token}@|"
    elif [[ "$url" =~ ^git@ ]]; then
        # SSH URL: convert to HTTPS with token
        local host_and_path=$(echo "$url" | sed 's|git@||' | sed 's|:|/|')
        echo "https://oauth2:${token}@${host_and_path}"
    else
        print_error "Unsupported URL format: $url"
        exit 1
    fi
}

# Push with retry logic and exponential backoff
push_with_retry() {
    local remote="$1"
    local branch="$2"
    shift 2
    local additional_args=("$@")
    local token
    local remote_url
    local auth_url
    local attempt=1
    local backoff=$INITIAL_BACKOFF

    # Get token
    token=$(get_token)

    # Get remote URL
    remote_url=$(get_remote_url "$remote")
    if [ -z "$remote_url" ]; then
        print_error "Remote '$remote' not found"
        exit 1
    fi

    # Inject token into URL
    auth_url=$(inject_token_to_url "$remote_url" "$token")

    print_info "Pushing to $remote/$branch..."

    while [ $attempt -le $MAX_RETRIES ]; do
        if [ $attempt -gt 1 ]; then
            print_warning "Retry attempt $attempt of $MAX_RETRIES (waiting ${backoff}s)..."
            sleep $backoff
        fi

        # Attempt to push using the authenticated URL
        if git push "$auth_url" "$branch" "${additional_args[@]}" 2>&1; then
            print_success "Successfully pushed to $remote/$branch"
            return 0
        else
            local exit_code=$?

            # Check if it's a network error (retry) or auth error (fail immediately)
            if [ $exit_code -eq 128 ]; then
                print_error "Authentication failed. Check your token and permissions."
                exit 1
            fi

            if [ $attempt -eq $MAX_RETRIES ]; then
                print_error "Failed to push after $MAX_RETRIES attempts"
                exit 1
            fi

            # Exponential backoff
            ((attempt++))
            backoff=$((backoff * 2))
        fi
    done
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [remote] [branch] [additional-git-push-args]

Examples:
  $0                        # Push current branch to origin
  $0 origin main            # Push main branch to origin
  $0 origin feature -f      # Force push feature branch
  $0 upstream develop --tags # Push develop branch with tags

Arguments:
  remote  Git remote name (default: origin)
  branch  Branch name (default: current branch)

The script will automatically retry up to $MAX_RETRIES times with exponential backoff
on network failures.
EOF
}

# Main function
main() {
    # Check for help flag
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi

    # Validate environment
    check_git_repo
    check_token_exists

    # Parse arguments
    local remote="${1:-origin}"
    local branch="${2:-$(get_current_branch)}"
    shift 2 2>/dev/null || shift $# # Remove first two args if they exist
    local additional_args=("$@")

    # Validate branch is not empty
    if [ -z "$branch" ]; then
        print_error "Could not determine branch name"
        exit 1
    fi

    # Show what we're doing
    echo "========================================="
    echo "  GitLab Secure Push"
    echo "========================================="
    print_info "Remote: $remote"
    print_info "Branch: $branch"
    if [ ${#additional_args[@]} -gt 0 ]; then
        print_info "Additional args: ${additional_args[*]}"
    fi
    echo

    # Perform the push with retry logic
    push_with_retry "$remote" "$branch" "${additional_args[@]}"
}

main "$@"
