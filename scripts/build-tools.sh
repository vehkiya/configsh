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
# Prefers go install, falls back to precompiled GitHub Release binary
# -----------------------------------------------------------------------------
installed=false

if command -v go &>/dev/null; then
    info "Installing sshx via go install github.com/vehkiya/sshx@latest..."
    if GOBIN="$BIN_DIR" CGO_ENABLED=0 go install -trimpath -ldflags="-s -w" github.com/vehkiya/sshx@latest 2>/dev/null; then
        chmod 755 "$BIN_DIR/sshx"
        success "Installed sshx (via go install)"
        installed=true
    else
        warn "go install failed, falling back to precompiled GitHub release..."
    fi
fi

if [ "$installed" = false ]; then
    info "Downloading prebuilt sshx binary from GitHub Releases..."
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
    esac
    TAR_URL="https://github.com/vehkiya/sshx/releases/latest/download/sshx_${OS}_${ARCH}.tar.gz"
    if curl -sSLf "$TAR_URL" -o /tmp/sshx.tar.gz 2>/dev/null; then
        tar -xzf /tmp/sshx.tar.gz -C /tmp/
        mv /tmp/sshx "$BIN_DIR/sshx"
        chmod 755 "$BIN_DIR/sshx"
        rm -f /tmp/sshx.tar.gz
        success "Installed sshx (from GitHub Releases)"
        installed=true
    else
        warn "Could not download prebuilt sshx release. Install Go or download manually from https://github.com/vehkiya/sshx/releases"
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
