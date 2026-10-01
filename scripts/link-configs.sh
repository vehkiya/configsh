#!/usr/bin/env bash
# =============================================================================
# scripts/link-configs.sh - Symlink Configuration Files & Installer Rescue
# =============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

info "1. Setting up configuration symlinks..."

link_file() {
    local src="$1"
    local dest="$2"
    local dest_dir
    dest_dir="$(dirname "$dest")"

    mkdir -p "$dest_dir"

    if [ -L "$dest" ]; then
        if [ "$(readlink "$dest")" = "$src" ]; then
            success "Already linked: $dest -> $src"
            return
        fi
        rm -f "$dest"
    elif [ -e "$dest" ]; then
        warn "Backing up existing file: $dest -> ${dest}.bak"
        mv "$dest" "${dest}.bak"
    fi

    ln -s "$src" "$dest"
    success "Linked: $dest -> $src"
}

# -----------------------------------------------------------------------------
# Zshrc Installer Diff & Rescue (Scenarios A & B)
# -----------------------------------------------------------------------------
rescue_zshrc_installer_changes() {
    if [ -d "$DOTFILES_DIR/.git" ] && command -v git &>/dev/null; then
        if ! git -C "$DOTFILES_DIR" diff --quiet .zshrc 2>/dev/null; then
            echo ""
            warn "Detected uncommitted modifications in .zshrc (likely appended by an installer):"

            local added_lines
            added_lines="$(git -C "$DOTFILES_DIR" diff -U0 .zshrc | grep '^[+]' | grep -v '^[+][+][+]' | sed 's/^[+]//' || true)"

            if [ -n "$added_lines" ]; then
                echo -e "${YELLOW}----------------------------------------------------------------${RESET}"
                echo "$added_lines"
                echo -e "${YELLOW}----------------------------------------------------------------${RESET}"

                local rescue_choice="y"
                if [ "${ASSUME_YES:-false}" != true ]; then
                    read -r -p "Migrate these lines to ~/.zshrc.local and clean git repo? [Y/n] " rescue_choice || rescue_choice="y"
                    rescue_choice="${rescue_choice:-y}"
                fi

                if [[ "$rescue_choice" =~ ^[Yy]$ ]]; then
                    mkdir -p "$(dirname "$HOME/.zshrc.local")"
                    {
                        echo ""
                        echo "# -----------------------------------------------------------------------------"
                        echo "# Auto-rescued from .zshrc on $(date '+%Y-%m-%d %H:%M:%S')"
                        echo "# -----------------------------------------------------------------------------"
                        echo "$added_lines"
                    } >> "$HOME/.zshrc.local"
                    chmod 600 "$HOME/.zshrc.local"

                    git -C "$DOTFILES_DIR" checkout .zshrc &>/dev/null || git -C "$DOTFILES_DIR" restore .zshrc &>/dev/null
                    success "Migrated installer additions to ~/.zshrc.local and restored clean .zshrc in git!"
                fi
            fi
            echo ""
        fi
    fi
}

rescue_physical_zshrc() {
    local target="$HOME/.zshrc"
    local repo_zshrc="$DOTFILES_DIR/.zshrc"

    if [ -f "$target" ] && [ ! -L "$target" ]; then
        warn "Found existing physical file at $target (not a symlink)."

        local unique_lines=""
        while IFS= read -r line || [ -n "$line" ]; do
            local trimmed
            trimmed="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            [[ -z "$trimmed" || "$trimmed" =~ ^# ]] && continue

            if ! grep -Fxq "$line" "$repo_zshrc" 2>/dev/null && ! grep -Fxq "$trimmed" "$repo_zshrc" 2>/dev/null; then
                unique_lines+="$line"$'\n'
            fi
        done < "$target"

        if [ -n "$unique_lines" ]; then
            info "Detected custom or installer configuration in existing ~/.zshrc:"
            echo -e "${CYAN}----------------------------------------------------------------${RESET}"
            echo -n "$unique_lines"
            echo -e "${CYAN}----------------------------------------------------------------${RESET}"

            local migrate_choice="y"
            if [ "${ASSUME_YES:-false}" != true ]; then
                read -r -p "Migrate these custom lines to ~/.zshrc.local before symlinking? [Y/n] " migrate_choice || migrate_choice="y"
                migrate_choice="${migrate_choice:-y}"
            fi

            if [[ "$migrate_choice" =~ ^[Yy]$ ]]; then
                mkdir -p "$(dirname "$HOME/.zshrc.local")"
                {
                    echo ""
                    echo "# -----------------------------------------------------------------------------"
                    echo "# Rescued from physical ~/.zshrc on $(date '+%Y-%m-%d %H:%M:%S')"
                    echo "# -----------------------------------------------------------------------------"
                    echo -n "$unique_lines"
                } >> "$HOME/.zshrc.local"
                chmod 600 "$HOME/.zshrc.local"
                success "Migrated custom configuration to ~/.zshrc.local"
            fi
        fi

        warn "Backing up physical $target to ${target}.bak"
        mv "$target" "${target}.bak"
    fi
}

# Run zshrc rescue checks for Scenarios A & B
rescue_zshrc_installer_changes
rescue_physical_zshrc

# Link .zshrc
link_file "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

# Link starship.toml
link_file "$DOTFILES_DIR/.config/starship.toml" "$HOME/.config/starship.toml"

# Link Ghostty config (only if Ghostty is installed or previously configured)
if command -v ghostty &>/dev/null || [ -d "/Applications/Ghostty.app" ] || [ -f "/usr/lib/systemd/user/app-com.mitchellh.ghostty.service" ] || [ -L "$HOME/.config/ghostty/config" ]; then
    link_file "$DOTFILES_DIR/.config/ghostty/config.ghostty" "$HOME/.config/ghostty/config.ghostty"
    link_file "$DOTFILES_DIR/.config/ghostty/config" "$HOME/.config/ghostty/config"

    # macOS Ghostty alternative location support
    if [ "$OS" = "Darwin" ]; then
        GHOSTTY_MAC_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
        mkdir -p "$GHOSTTY_MAC_DIR"
        link_file "$DOTFILES_DIR/.config/ghostty/config" "$GHOSTTY_MAC_DIR/config"
    fi
else
    success "Ghostty not installed; skipping Ghostty configuration symlinks."
fi

# Link direnvrc (secret helpers for OpenBao/Vault & pass)
link_file "$DOTFILES_DIR/.config/direnv/direnvrc" "$HOME/.config/direnv/direnvrc"

# Link pinentry-wrapper (adaptive GUI/CLI with OS keychain support)
chmod +x "$DOTFILES_DIR/scripts/pinentry-wrapper.sh"
link_file "$DOTFILES_DIR/scripts/pinentry-wrapper.sh" "$HOME/.local/bin/pinentry-wrapper"

# Ensure ~/.zshrc.local template exists with private permissions
if [ ! -f "$HOME/.zshrc.local" ]; then
    cat <<'EOF' > "$HOME/.zshrc.local"
# Local / Machine-specific secrets & environment overrides
# This file is ignored by Git in configsh. Never commit API keys or credentials.
EOF
    chmod 600 "$HOME/.zshrc.local"
    success "Created empty ~/.zshrc.local template (chmod 600)"
else
    chmod 600 "$HOME/.zshrc.local"
    success "Secured ~/.zshrc.local permissions (chmod 600)"
fi

# Check if zoxide cd-replacement preference is set in ~/.zshrc.local
if command -v zoxide &>/dev/null && [ "${ASSUME_YES:-false}" != true ]; then
    if ! grep -q "ZOXIDE_REPLACE_CD" "$HOME/.zshrc.local" 2>/dev/null; then
        echo ""
        info "Zoxide is installed. It provides 'z' & 'zi', but can also replace 'cd' completely."
        read -r -p "Would you like zoxide to replace the standard 'cd' command completely? [y/N] " replace_cd_ans || replace_cd_ans="n"
        replace_cd_ans="${replace_cd_ans:-n}"
        if [[ "$replace_cd_ans" =~ ^[Yy]$ ]]; then
            echo "" >> "$HOME/.zshrc.local"
            echo '# Zoxide: Replace standard cd command' >> "$HOME/.zshrc.local"
            echo 'export ZOXIDE_REPLACE_CD="${ZOXIDE_REPLACE_CD:-true}"' >> "$HOME/.zshrc.local"
            success "Configured zoxide to replace 'cd' (ZOXIDE_REPLACE_CD=true in ~/.zshrc.local)"
        else
            echo "" >> "$HOME/.zshrc.local"
            echo '# Zoxide: Keep standard cd, use z and zi' >> "$HOME/.zshrc.local"
            echo 'export ZOXIDE_REPLACE_CD="${ZOXIDE_REPLACE_CD:-false}"' >> "$HOME/.zshrc.local"
            success "Kept standard 'cd'; use 'z' and 'zi' for zoxide jumping"
        fi
    fi
fi

echo ""
