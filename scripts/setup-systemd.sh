#!/usr/bin/env bash
# =============================================================================
# scripts/setup-systemd.sh - Linux Ghostty Systemd Service Override
# =============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

if [ "$OS" = "Linux" ]; then
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
            systemctl --user daemon-reload 2>/dev/null || true
            success "Reloaded systemd user daemon"
        fi
    else
        success "Ghostty systemd service not present; skipping override."
    fi
    echo ""
fi
