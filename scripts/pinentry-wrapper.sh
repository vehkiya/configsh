#!/usr/bin/env bash
# =============================================================================
# pinentry-wrapper - Adaptive GUI/CLI pinentry for GPG with OS Keychain support
# Supports: macOS (Keychain via pinentry-mac) & Linux (KWallet via pinentry-qt,
#           GNOME Keyring via pinentry-gnome3, or terminal curses fallback)
# =============================================================================

# 1. Graphical Environment (macOS Quartz / Wayland / X11)
# macOS sets neither DISPLAY nor WAYLAND_DISPLAY, so it's checked on its own
if [ "$(uname)" = "Darwin" ]; then
    if [ -x "/opt/homebrew/bin/pinentry-mac" ]; then
        exec /opt/homebrew/bin/pinentry-mac "$@"
    elif [ -x "/usr/local/bin/pinentry-mac" ]; then
        exec /usr/local/bin/pinentry-mac "$@"
    fi
elif [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; then
    # Prefer KDE pinentry-qt under KDE/Plasma
    if [[ "${XDG_CURRENT_DESKTOP:-}" =~ [Kk][Dd][Ee] ]] && command -v pinentry-qt &>/dev/null; then
        exec "$(command -v pinentry-qt)" "$@"
    elif command -v pinentry-gnome3 &>/dev/null; then
        exec "$(command -v pinentry-gnome3)" "$@"
    elif command -v pinentry-qt &>/dev/null; then
        exec "$(command -v pinentry-qt)" "$@"
    elif command -v pinentry-gtk-2 &>/dev/null; then
        exec "$(command -v pinentry-gtk-2)" "$@"
    fi
fi

# 2. Terminal / Headless / SSH Fallback
if command -v pinentry-curses &>/dev/null; then
    exec "$(command -v pinentry-curses)" "$@"
elif command -v pinentry-tty &>/dev/null; then
    exec "$(command -v pinentry-tty)" "$@"
fi

# 3. Final default fallback
exec pinentry "$@"
