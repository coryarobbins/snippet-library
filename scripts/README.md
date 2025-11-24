# GitLab Secure Push Scripts

A secure solution for pushing to GitLab repositories using encrypted personal access tokens on Ubuntu servers without GUI.

## Features

- **Secure Token Storage**: Personal access tokens are encrypted using GPG (AES256)
- **No GUI Required**: Fully command-line based for server environments
- **Automatic Retry**: Built-in retry logic with exponential backoff for network failures
- **Easy Setup**: Simple initialization process
- **Flexible Usage**: Works with any GitLab repository and supports all git push options

## Requirements

- Ubuntu Server (or any Linux with bash)
- GPG (GnuPG) - `sudo apt-get install gnupg`
- Git - `sudo apt-get install git`

## Installation

1. Make the scripts executable:
```bash
chmod +x gitlab-token-setup.sh gitlab-push.sh
```

2. Run the setup script:
```bash
./gitlab-token-setup.sh
```

This will:
- Check for required dependencies
- Create a GPG key if needed (or use existing)
- Prompt for your GitLab personal access token
- Encrypt and store the token securely

## Creating a GitLab Personal Access Token

1. Log in to your GitLab instance
2. Go to **Settings** → **Access Tokens** (or **Preferences** → **Access Tokens**)
3. Create a new token with the following scope:
   - `write_repository` (required for pushing)
4. Copy the token (you won't be able to see it again)
5. Use it during the setup process

## Usage

### Basic Usage

Push current branch to origin:
```bash
./gitlab-push.sh
```

### Specify Remote and Branch

```bash
./gitlab-push.sh origin main
```

### Force Push

```bash
./gitlab-push.sh origin feature-branch --force
```

### Push with Tags

```bash
./gitlab-push.sh origin main --tags
```

### Set Upstream

```bash
./gitlab-push.sh origin feature-branch -u
```

## How It Works

### Security

1. **Token Encryption**: Your personal access token is encrypted using GPG with AES256 cipher
2. **Secure Storage**: The encrypted token is stored at `~/.config/gitlab-tokens/token.gpg` with 600 permissions
3. **Memory Safety**: The token is only decrypted in memory when needed and never written to disk in plain text
4. **URL Injection**: The token is temporarily injected into the Git remote URL for authentication

### Retry Logic

The push script includes automatic retry with exponential backoff:
- **Maximum Retries**: 4 attempts
- **Backoff Pattern**: 2s, 4s, 8s, 16s
- **Network Failures**: Automatically retried
- **Auth Failures**: Fail immediately (no retry)

## File Locations

- **Encrypted Token**: `~/.config/gitlab-tokens/token.gpg`
- **Scripts**: Current directory or wherever you place them

## Troubleshooting

### Token Decryption Fails

If you're prompted for a password when running `gitlab-push.sh`:
- Enter the password you used when running `gitlab-token-setup.sh`
- This is your GPG passphrase, not your GitLab password

### Authentication Failed (403)

- Verify your token has the correct scope (`write_repository`)
- Check if the token has expired
- Run `./gitlab-token-setup.sh` again to update the token

### Not in a Git Repository

Make sure you're running the script from within a git repository:
```bash
cd /path/to/your/repo
/path/to/gitlab-push.sh
```

### Network Errors

The script will automatically retry up to 4 times with exponential backoff. If all retries fail:
- Check your internet connection
- Verify the GitLab server is accessible
- Check your firewall settings

## Updating Your Token

To update or replace your stored token:
```bash
./gitlab-token-setup.sh
```

Answer 'y' when prompted to replace the existing token.

## Security Considerations

### Best Practices

1. **Token Scope**: Only grant the minimum required scope (`write_repository`)
2. **Token Expiration**: Set an expiration date on your tokens
3. **File Permissions**: The scripts maintain secure permissions (600) on the token file
4. **Server Access**: Ensure only authorized users have access to your server account
5. **GPG Passphrase**: Use a strong passphrase for your GPG key

### Alternative Security Options

If you need even more security:

1. **Hardware Tokens**: Use a YubiKey or similar for GPG key storage
2. **SSH Keys**: Consider using SSH keys instead of HTTPS with tokens
3. **Credential Helpers**: Use git-credential-cache with a timeout
4. **Separate GPG Key**: Create a dedicated GPG key just for token encryption

### SSH Alternative

For maximum security, consider using SSH keys instead:
```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Add to GitLab (Settings → SSH Keys)
cat ~/.ssh/id_ed25519.pub

# Use SSH URL for your remote
git remote set-url origin git@gitlab.com:username/repo.git
```

## Uninstallation

To remove the stored token:
```bash
rm -rf ~/.config/gitlab-tokens
```

To remove your GPG key (if created by this script):
```bash
gpg --list-keys  # Find the key ID
gpg --delete-secret-keys KEY_ID
gpg --delete-keys KEY_ID
```

## License

This script is provided as-is for use with GitLab repositories.

## Version

1.0.0

## Support

For issues or questions, please contact your GitLab administrator or refer to the GitLab documentation.
