#!/usr/bin/env bash
# =============================================================================
# scripts/audit-ssh-keys.sh - Audit SSH Private Keys for Passphrase Protection
# =============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

info "4. Auditing SSH private keys for passphrase protection..."

UNENCRYPTED_COUNT=0
if [ -d "$HOME/.ssh" ]; then
    while IFS= read -r key; do
        if [ -f "$key" ]; then
            # Test if the key can be read without a passphrase
            if ssh-keygen -y -P "" -f "$key" >/dev/null 2>&1; then
                alert "UNENCRYPTED KEY DETECTED: $key"
                echo -e "    ${YELLOW}↳ Add a passphrase: ${BOLD}ssh-keygen -p -f $key${RESET}"
                UNENCRYPTED_COUNT=$((UNENCRYPTED_COUNT + 1))
            else
                success "Encrypted with passphrase: $(basename "$key")"
            fi
        fi
    done < <(find "$HOME/.ssh" -maxdepth 1 -type f ! -name "*.pub" ! -name "known_hosts*" ! -name "authorized_keys*" ! -name "allowed_signers*" ! -name "config" 2>/dev/null || true)
fi

if [ "$UNENCRYPTED_COUNT" -eq 0 ]; then
    success "All detected SSH private keys are passphrase-protected."
else
    warn "$UNENCRYPTED_COUNT SSH key(s) on disk have empty passphrases. Encrypt them to prevent offline exfiltration."
fi

echo ""
