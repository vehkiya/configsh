#!/usr/bin/env bash
# =============================================================================
# scripts/lib/common.sh - Shared Environment, Formatting & Logging
# =============================================================================

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OS="$(uname -s)"
export DOTFILES_DIR OS

# Color formatting
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
RED="\033[0;31m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

info()    { echo -e "${BLUE}==>${RESET} ${BOLD}$1${RESET}"; }
success() { echo -e "${GREEN}  ✓${RESET} $1"; }
warn()    { echo -e "${YELLOW}  ⚠${RESET} $1"; }
alert()   { echo -e "${RED}  ✗${RESET} $1"; }
header()  { echo -e "\n${BOLD}${CYAN}$1${RESET}"; }

# Pick a backup path that never overwrites an earlier backup
backup_path() {
    local path="$1" dest="${1}.bak" ts i=1
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        ts="$(date '+%Y%m%d%H%M%S')"
        dest="${path}.bak.${ts}"
        while [ -e "$dest" ] || [ -L "$dest" ]; do
            dest="${path}.bak.${ts}.${i}"
            i=$((i + 1))
        done
    fi
    echo "$dest"
}

# Replace a file with a fully written temp file: an atomic rename for regular
# files, a write-through for symlinks (e.g. a dotfiles-managed ~/.ssh/config)
# so the link itself survives
replace_file() {
    local tmp="$1" dest="$2"
    if [ -L "$dest" ]; then
        cat "$tmp" > "$dest" && rm -f "$tmp"
    else
        mv "$tmp" "$dest"
    fi
}

# List SSH private keys in ~/.ssh (only files with a private key header, so
# configs, backups and other files aren't mistaken for keys)
ssh_private_keys() {
    local f
    for f in "$HOME/.ssh"/*; do
        [ -f "$f" ] || continue
        case "$f" in *.pub) continue ;; esac
        if head -n 1 "$f" 2>/dev/null | grep -q -e '-----BEGIN .*PRIVATE KEY-----'; then
            echo "$f"
        fi
    done
}

# Classify an SSH private key as "encrypted", "unencrypted", or "fido" (an
# unencrypted security-key handle, which is useless without the hardware key)
ssh_key_protection() {
    local pub
    # Security-key handles are recognised from their .pub when present, so
    # ssh-keygen never has to load them
    if [ -f "$1.pub" ] && grep -q '^sk-' "$1.pub"; then
        echo "fido"
    elif ! pub="$(ssh-keygen -y -P "" -f "$1" 2>/dev/null)"; then
        echo "encrypted"
    elif [[ "$pub" == sk-* ]]; then
        echo "fido"
    else
        echo "unencrypted"
    fi
}

# Parse common flags (-y / --yes)
ASSUME_YES="${ASSUME_YES:-false}"
for arg in "$@"; do
    case "$arg" in
        -y|--yes)
            ASSUME_YES=true
            ;;
    esac
done
export ASSUME_YES
