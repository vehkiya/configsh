#!/usr/bin/env bash
# =============================================================================
# scripts/setup-systemd.sh - Linux Ghostty Systemd Service Override
# =============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

if [ "$OS" = "Linux" ]; then
    if is_wsl; then
        info "5. Skipping Ghostty systemd integration (running inside WSL; host terminal used)..."
    else
        info "5. Checking Linux Ghostty systemd integration..."
        GHOSTTY_OVERRIDE_DIR="$HOME/.config/systemd/user/app-com.mitchellh.ghostty.service.d"
        GHOSTTY_OVERRIDE_FILE="$GHOSTTY_OVERRIDE_DIR/override.conf"

        if [ -f "/usr/lib/systemd/user/app-com.mitchellh.ghostty.service" ] || command -v ghostty &>/dev/null; then
            mkdir -p "$GHOSTTY_OVERRIDE_DIR"
            cat <<'EOF' > "$GHOSTTY_OVERRIDE_FILE"
[Service]
Type=notify
EOF
            success "Applied Ghostty systemd override (Type=notify in $GHOSTTY_OVERRIDE_FILE)"
            if command -v systemctl &>/dev/null; then
                if systemctl --user daemon-reload 2>/dev/null; then
                    success "Reloaded systemd user daemon"
                else
                    warn "Could not reload the systemd user daemon; the override applies after the next login"
                fi
            fi
        else
            success "Ghostty not installed or systemd service not present; skipping override."
        fi
    fi
    echo ""
fi
