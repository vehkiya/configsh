#!/usr/bin/env bash
# =============================================================================
# scripts/build-tools.sh - Install Native Utilities to ~/.local/bin
# Supports: macOS (Darwin ARM/Intel) & Linux
# =============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" 2>/dev/null || true

header "Native Utility Binaries"

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

# Clean up obsolete aliases/symlinks if present
rm -f "$BIN_DIR/ssh-add-host" "$BIN_DIR/add-ssh-host" "$BIN_DIR/fssh-add" 2>/dev/null || true

# -----------------------------------------------------------------------------
# 1. Install sshx (https://github.com/vehkiya/sshx)
# Prefers go install, falls back to precompiled GitHub Release binary.
# Set SSHX_VERSION (e.g. v0.5.0) to pin a release instead of tracking latest.
# -----------------------------------------------------------------------------
SSHX_VERSION="${SSHX_VERSION:-latest}"
installed=false

sha256_of() {
    if command -v sha256sum &>/dev/null; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

if command -v go &>/dev/null; then
    info "Installing sshx via go install github.com/vehkiya/sshx@${SSHX_VERSION}..."
    if GOBIN="$BIN_DIR" CGO_ENABLED=0 go install -trimpath -ldflags="-s -w" "github.com/vehkiya/sshx@${SSHX_VERSION}"; then
        chmod 755 "$BIN_DIR/sshx"
        success "Installed sshx (via go install)"
        installed=true
    else
        warn "go install failed, falling back to precompiled GitHub release..."
    fi
fi

if [ "$installed" = false ]; then
    info "Downloading prebuilt sshx binary from GitHub Releases..."
    SSHX_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    SSHX_ARCH="$(uname -m)"
    case "$SSHX_ARCH" in
        x86_64) SSHX_ARCH="amd64" ;;
        aarch64|arm64) SSHX_ARCH="arm64" ;;
    esac
    if [ "$SSHX_VERSION" = "latest" ]; then
        RELEASE_URL="https://github.com/vehkiya/sshx/releases/latest/download"
    else
        RELEASE_URL="https://github.com/vehkiya/sshx/releases/download/${SSHX_VERSION}"
    fi
    TARBALL="sshx_${SSHX_OS}_${SSHX_ARCH}.tar.gz"

    # Private temp dir (not fixed /tmp paths), cleaned up by the subshell's trap.
    # Every step checks its own status: set -e doesn't apply inside an if condition.
    if (
        tmp="$(mktemp -d)" || exit 1
        trap 'rm -rf "$tmp"' EXIT
        curl -sSLf "$RELEASE_URL/$TARBALL" -o "$tmp/$TARBALL" || exit 1
        curl -sSLf "$RELEASE_URL/checksums.txt" -o "$tmp/checksums.txt" || exit 1
        expected="$(awk -v f="$TARBALL" '$2 == f { print $1 }' "$tmp/checksums.txt")"
        if [ -z "$expected" ] || [ "$expected" != "$(sha256_of "$tmp/$TARBALL")" ]; then
            alert "Checksum verification failed for $TARBALL"
            exit 1
        fi
        tar -xzf "$tmp/$TARBALL" -C "$tmp" || exit 1
        bin="$(find "$tmp" -type f -name sshx | head -n 1)"
        [ -n "$bin" ] || exit 1
        mv "$bin" "$BIN_DIR/sshx" && chmod 755 "$BIN_DIR/sshx"
    ); then
        success "Installed sshx (from GitHub Releases, checksum verified)"
        installed=true
    else
        warn "Could not install prebuilt sshx release. Install Go or download manually from https://github.com/vehkiya/sshx/releases"
    fi
fi

# -----------------------------------------------------------------------------
# 2. Build any custom dotfiles utilities in cmd/ (if present)
# -----------------------------------------------------------------------------
if [ -d "$DOTFILES_DIR/cmd" ]; then
    for tool_dir in "$DOTFILES_DIR"/cmd/*; do
        if [ -d "$tool_dir" ]; then
            tool_name="$(basename "$tool_dir")"
            info "Compiling $tool_name -> $BIN_DIR/$tool_name..."
            (
                cd "$DOTFILES_DIR"
                CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o "$BIN_DIR/$tool_name" "./cmd/$tool_name"
            )
            chmod 755 "$BIN_DIR/$tool_name"
            success "Installed $tool_name"
        fi
    done
fi
