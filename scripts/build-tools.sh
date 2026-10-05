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

sha256_of() {
    if command -v sha256sum &>/dev/null; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# install_tool NAME VERSION: installs github.com/vehkiya/NAME into $BIN_DIR.
# Prefers go install, and falls back to the precompiled GitHub Release binary,
# checking it against the release's SHA-256 checksums. VERSION is "latest" or
# a release tag such as v0.5.0.
install_tool() {
    local name="$1" version="$2" repo="vehkiya/$1"

    if command -v go &>/dev/null; then
        info "Installing $name via go install github.com/$repo@${version}..."
        if GOBIN="$BIN_DIR" CGO_ENABLED=0 go install -trimpath -ldflags="-s -w" "github.com/$repo@${version}"; then
            chmod 755 "$BIN_DIR/$name"
            success "Installed $name (via go install)"
            return 0
        fi
        warn "go install failed, falling back to precompiled GitHub release..."
    fi

    info "Downloading prebuilt $name binary from GitHub Releases..."
    local os arch release_url tarball
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"
    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
    esac
    if [ "$version" = "latest" ]; then
        release_url="https://github.com/$repo/releases/latest/download"
    else
        release_url="https://github.com/$repo/releases/download/${version}"
    fi
    tarball="${name}_${os}_${arch}.tar.gz"

    # Private temp dir (not fixed /tmp paths), cleaned up by the subshell's trap.
    # Every step checks its own status: set -e doesn't apply inside an if condition.
    if (
        tmp="$(mktemp -d)" || exit 1
        trap 'rm -rf "$tmp"' EXIT
        curl -sSLf "$release_url/$tarball" -o "$tmp/$tarball" || exit 1
        curl -sSLf "$release_url/checksums.txt" -o "$tmp/checksums.txt" || exit 1
        expected="$(awk -v f="$tarball" '$2 == f { print $1 }' "$tmp/checksums.txt")"
        if [ -z "$expected" ] || [ "$expected" != "$(sha256_of "$tmp/$tarball")" ]; then
            alert "Checksum verification failed for $tarball"
            exit 1
        fi
        tar -xzf "$tmp/$tarball" -C "$tmp" || exit 1
        bin="$(find "$tmp" -type f -name "$name" | head -n 1)"
        [ -n "$bin" ] || exit 1
        mv "$bin" "$BIN_DIR/$name" && chmod 755 "$BIN_DIR/$name"
    ); then
        success "Installed $name (from GitHub Releases, checksum verified)"
    else
        warn "Could not install prebuilt $name release. Install Go or download manually from https://github.com/$repo/releases"
    fi
}

# -----------------------------------------------------------------------------
# 1. Install sshx (https://github.com/vehkiya/sshx), the SSH host manager.
# Set SSHX_VERSION (e.g. v0.5.0) to pin a release instead of tracking latest.
# -----------------------------------------------------------------------------
install_tool sshx "${SSHX_VERSION:-latest}"

# -----------------------------------------------------------------------------
# 2. Install doppel (https://github.com/vehkiya/doppel), Git accounts per folder.
# Set DOPPEL_VERSION (e.g. v0.5.0) to pin a release instead of tracking latest.
# -----------------------------------------------------------------------------
install_tool doppel "${DOPPEL_VERSION:-latest}"

# -----------------------------------------------------------------------------
# 3. Build any custom dotfiles utilities in cmd/ (if present)
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
