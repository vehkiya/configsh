#!/usr/bin/env bash
# =============================================================================
# scripts/build-tools.sh - Install/Compile Native Utilities to ~/.local/bin
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

# -----------------------------------------------------------------------------
# 1. Install or compile sshx (https://github.com/vehkiya/sshx)
# -----------------------------------------------------------------------------
if [ -d "$HOME/projects/sshx" ]; then
    info "Compiling sshx from local repository ($HOME/projects/sshx)..."
    (
        cd "$HOME/projects/sshx"
        COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
        CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X main.Commit=${COMMIT}" -o "$BIN_DIR/sshx" .
    )
    chmod 755 "$BIN_DIR/sshx"
    success "Installed sshx (from local repo)"
elif command -v go &>/dev/null; then
    info "Installing sshx via go install github.com/vehkiya/sshx@latest..."
    GOBIN="$BIN_DIR" CGO_ENABLED=0 go install -trimpath -ldflags="-s -w" github.com/vehkiya/sshx@latest
    chmod 755 "$BIN_DIR/sshx"
    success "Installed sshx (via go install)"
else
    warn "Go compiler not found. Attempting to download prebuilt sshx binary..."
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
    else
        warn "Could not download prebuilt sshx release. Install Go or download manually from https://github.com/vehkiya/sshx/releases"
    fi
fi

# Symlink backwards-compatible aliases
if [ -x "$BIN_DIR/sshx" ]; then
    ln -sf "$BIN_DIR/sshx" "$BIN_DIR/ssh-add-host"
    success "Linked ssh-add-host -> sshx"
fi

# -----------------------------------------------------------------------------
# 2. Build any custom dotfiles utilities in cmd/
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
