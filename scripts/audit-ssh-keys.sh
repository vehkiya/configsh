#!/usr/bin/env bash
# =============================================================================
# scripts/audit-ssh-keys.sh - Audit SSH Private Keys for Passphrase Protection
# =============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

info "4. Auditing SSH private keys for passphrase protection..."

KEY_COUNT=0
UNENCRYPTED_COUNT=0
while IFS= read -r key; do
    KEY_COUNT=$((KEY_COUNT + 1))
    case "$(ssh_key_protection "$key")" in
        encrypted) success "Encrypted with passphrase: $(basename "$key")" ;;
        fido)      success "Hardware-backed FIDO key: $(basename "$key")" ;;
        *)
            alert "UNENCRYPTED KEY DETECTED: $key"
            echo -e "    ${YELLOW}↳ Add a passphrase: ${BOLD}ssh-keygen -p -f $key${RESET}"
            UNENCRYPTED_COUNT=$((UNENCRYPTED_COUNT + 1))
            ;;
    esac
done < <(ssh_private_keys)

if [ "$KEY_COUNT" -eq 0 ]; then
    success "No SSH private keys found in ~/.ssh."
elif [ "$UNENCRYPTED_COUNT" -eq 0 ]; then
    success "No unencrypted SSH private keys found."
else
    warn "$UNENCRYPTED_COUNT SSH key(s) on disk have empty passphrases. Encrypt them to prevent offline exfiltration."
fi

echo ""
