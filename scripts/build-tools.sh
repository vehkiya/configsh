#!/usr/bin/env bash
# =============================================================================
# scripts/build-tools.sh - Compile Native Go Utilities to ~/.local/bin
# Supports: macOS (Darwin ARM/Intel) & Linux
# =============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" 2>/dev/null || true

header "Native Utility Binaries (Go)"

if ! command -v go &>/dev/null; then
    warn "Go compiler is not installed. Skipping compilation of native tools in cmd/."
    warn "Install Go (via Homebrew, pacman, or apt) to enable helper tools like 'ssh-add-host'."
    return 0 2>/dev/null || exit 0
fi

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

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

    # Symlink backwards-compatible aliases
    if [ -x "$BIN_DIR/sshx" ]; then
        ln -sf "$BIN_DIR/sshx" "$BIN_DIR/ssh-add-host"
        success "Linked ssh-add-host -> sshx"
    fi
fi

