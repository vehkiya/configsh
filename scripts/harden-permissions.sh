#!/usr/bin/env bash
# =============================================================================
# scripts/harden-permissions.sh - Credential Permissions Hardening
# =============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

info "2. Hardening credential directories and file permissions..."

# Directories that should only be readable by the owner (700)
SECRET_DIRS=(
    "$HOME/.ssh"
    "$HOME/.aws"
    "$HOME/.kube"
    "$HOME/.talos"
    "$HOME/.docker"
    "$HOME/.config/gh"
    "$HOME/.gemini/config"
    "$HOME/.password-store"
    "$HOME/.gnupg"
)

for dir in "${SECRET_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        chmod 700 "$dir"
        success "chmod 700 $dir"
    fi
done

# Files that should only be readable/writable by the owner (600)
SECRET_FILES=(
    "$HOME/.ssh/config"
    "$HOME/.ssh/id_rsa"
    "$HOME/.ssh/id_ed25519"
    "$HOME/.ssh/id_ecdsa"
    "$HOME/.aws/credentials"
    "$HOME/.aws/config"
    "$HOME/.kube/config"
    "$HOME/.talos/config"
    "$HOME/.docker/config.json"
    "$HOME/.gemini/config/mcp_config.json"
    "$HOME/.zsh_history"
    "$HOME/.bash_history"
    "$HOME/.zshrc.local"
    "$HOME/.vault-token"
    "$HOME/.bao-token"
    "$HOME/.gnupg/gpg-agent.conf"
)

# Also include any private keys in ~/.ssh
if [ -d "$HOME/.ssh" ]; then
    while IFS= read -r key; do
        SECRET_FILES+=("$key")
    done < <(find "$HOME/.ssh" -maxdepth 1 -type f ! -name "*.pub" ! -name "known_hosts*" ! -name "authorized_keys*" ! -name "allowed_signers*" 2>/dev/null || true)
fi

for file in "${SECRET_FILES[@]}"; do
    if [ -f "$file" ]; then
        chmod 600 "$file"
        success "chmod 600 $file"
    fi
done

echo ""
