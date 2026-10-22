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

# True when `docker` is Podman's Docker-compatible shim (podman-docker), which
# runs rootless and needs no 'docker' group
docker_is_podman() {
    docker --version 2>/dev/null | grep -qi podman
}

# True when running inside Windows Subsystem for Linux (WSL)
is_wsl() {
    [ -n "${WSL_DISTRO_NAME:-}" ] || [ -n "${WSL_INTEROP:-}" ] || grep -qi -e 'microsoft' -e 'wsl' /proc/version 2>/dev/null
}

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

# Print how ssh sets AddKeysToAgent for every host ("true", "false", "ask",
# "confirm", ...): ssh -G on a host no entry names, so Include, Match and
# wildcards count as ssh counts them, and nothing connects. Prints nothing when
# ssh can't read the config. IgnoreUnknown keeps a non-Apple ssh from refusing
# a config that has UseKeychain.
ssh_adds_keys_for_all() {
    ssh -G -F "$1" -o IgnoreUnknown=UseKeychain configsh-no-such-host.invalid 2>/dev/null |
        awk '$1 == "addkeystoagent" { $1 = ""; sub(/^ /, ""); print; exit }'
}

# Print the value (lowercased) an ssh config sets for keyword where it applies
# to every host: before the first Host or Match line, or under "Host *" or
# "Match all". Prints nothing otherwise. For settings ssh -G doesn't print,
# such as Apple's UseKeychain; Include isn't followed.
ssh_config_catch_all() {
    [ -f "$1" ] || return 0
    awk -v kw="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')" '
        {
            line = $0
            sub(/^[ \t]+/, "", line)
            if (line == "" || line ~ /^#/) next
            gsub(/"/, "", line)
            n = split(line, f, /[ \t=]+/)
            key = tolower(f[1])
        }
        key == "host" {
            scoped = 1; all = 0
            for (i = 2; i <= n; i++) if (f[i] == "*") all = 1
            next
        }
        key == "match" { scoped = 1; all = (tolower(f[2]) == "all"); next }
        key == kw && (!scoped || all) { print tolower(f[2]); exit }
    ' "$1"
}

# True when the ssh on PATH is Apple's, the only one that can keep passphrases
# in the macOS Keychain: other builds (Homebrew's) refuse the UseKeychain option
ssh_is_apple() {
    ssh -G -F /dev/null -o UseKeychain=yes configsh-no-such-host.invalid >/dev/null 2>&1
}

# Mode management (minimal, required, full)
CONFIGSH_MODE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/configsh/mode"

get_configsh_mode() {
    if [ -n "${CONFIGSH_MODE:-}" ]; then
        echo "$CONFIGSH_MODE"
    elif [ -f "$CONFIGSH_MODE_FILE" ]; then
        local saved
        saved="$(tr -d '[:space:]' < "$CONFIGSH_MODE_FILE" 2>/dev/null || true)"
        case "$saved" in
            minimal|required|full) echo "$saved"; return ;;
        esac
        echo "required"
    else
        echo "required"
    fi
}

set_configsh_mode() {
    local mode="$1"
    mkdir -p "$(dirname "$CONFIGSH_MODE_FILE")"
    echo "$mode" > "$CONFIGSH_MODE_FILE"
}

mode_level() {
    case "$1" in
        minimal)  echo 1 ;;
        required) echo 2 ;;
        full)     echo 3 ;;
        *)        echo 2 ;;
    esac
}

# Parse common flags (-y / --yes, -m / --mode, minimal|required|full)
ASSUME_YES="${ASSUME_YES:-false}"
PARSED_MODE=""

for arg in "$@"; do
    case "$arg" in
        -y|--yes)
            ASSUME_YES=true
            ;;
        --mode=*)
            PARSED_MODE="${arg#*=}"
            ;;
        minimal|required|full)
            PARSED_MODE="$arg"
            ;;
    esac
done

prev=""
for arg in "$@"; do
    if [ "$prev" = "-m" ] || [ "$prev" = "--mode" ]; then
        case "$arg" in
            minimal|required|full) PARSED_MODE="$arg" ;;
        esac
    fi
    prev="$arg"
done

if [ -n "$PARSED_MODE" ]; then
    CONFIGSH_MODE="$PARSED_MODE"
else
    CONFIGSH_MODE="$(get_configsh_mode)"
fi

export ASSUME_YES CONFIGSH_MODE
