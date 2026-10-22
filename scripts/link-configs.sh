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
        local backup
        backup="$(backup_path "$dest")"
        warn "Backing up existing file: $dest -> $backup"
        mv "$dest" "$backup"
    fi

    ln -s "$src" "$dest"
    success "Linked: $dest -> $src"
}

# -----------------------------------------------------------------------------
# Zshrc Installer Diff & Rescue (Scenarios A & B)
# -----------------------------------------------------------------------------
# Scenario A: an installer appended to ~/.zshrc, i.e. to the repo's .zshrc via
# the symlink. Only a pure append (committed content + new lines at the end) is
# treated as installer output; any other uncommitted edit is left untouched so
# in-progress work on .zshrc is never reverted.
rescue_zshrc_installer_changes() {
    if [ ! -d "$DOTFILES_DIR/.git" ] || ! command -v git &>/dev/null; then
        return 0
    fi
    if git -C "$DOTFILES_DIR" diff --quiet HEAD -- .zshrc 2>/dev/null; then
        return 0
    fi

    local repo_zshrc="$DOTFILES_DIR/.zshrc"
    local committed_bytes
    committed_bytes="$(git -C "$DOTFILES_DIR" cat-file -s HEAD:.zshrc 2>/dev/null)" || return 0

    echo ""
    if ! head -c "$committed_bytes" "$repo_zshrc" | cmp -s - <(git -C "$DOTFILES_DIR" show HEAD:.zshrc); then
        warn "Uncommitted edits in .zshrc are not a simple append (manual changes?); leaving them untouched."
        echo -e "    ${YELLOW}↳ Commit or stash them to keep the repo clean.${RESET}"
        echo ""
        return 0
    fi

    local added_lines
    added_lines="$(tail -c +"$((committed_bytes + 1))" "$repo_zshrc")"
    if [ -z "${added_lines//[[:space:]]/}" ]; then
        git -C "$DOTFILES_DIR" checkout HEAD -- .zshrc
        return 0
    fi

    warn "Detected lines appended to .zshrc (likely by an installer):"
    echo -e "${YELLOW}----------------------------------------------------------------${RESET}"
    echo "$added_lines"
    echo -e "${YELLOW}----------------------------------------------------------------${RESET}"

    local rescue_choice="y"
    if [ "${ASSUME_YES:-false}" != true ]; then
        read -r -p "Move these lines to ~/.zshrc.local and restore the committed .zshrc? [Y/n] " rescue_choice || rescue_choice="y"
        rescue_choice="${rescue_choice:-y}"
    fi

    if [[ "$rescue_choice" =~ ^[Yy]$ ]]; then
        {
            echo ""
            echo "# -----------------------------------------------------------------------------"
            echo "# Auto-rescued from .zshrc on $(date '+%Y-%m-%d %H:%M:%S')"
            echo "# -----------------------------------------------------------------------------"
            echo "$added_lines"
        } >> "$HOME/.zshrc.local"
        chmod 600 "$HOME/.zshrc.local"

        git -C "$DOTFILES_DIR" checkout HEAD -- .zshrc
        success "Moved installer additions to ~/.zshrc.local and restored the committed .zshrc"
    fi
    echo ""
}

# Print the code lines of a zshrc minus comments and the Oh My Zsh boilerplate
# that this repo's .zshrc already owns (ZSH, ZSH_THEME, plugins=(...), sourcing
# oh-my-zsh.sh). Carrying those over would load OMZ a second time from
# ~/.zshrc.local and replace the Starship prompt with the template's theme.
zshrc_custom_code() {
    awk '
        { t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t) }
        in_plugins { if (t ~ /\)/) in_plugins = 0; next }
        t == "" || t ~ /^#/ { next }
        t ~ /^plugins=\(/ { if (t !~ /\)/) in_plugins = 1; next }
        t ~ /^(export[ \t]+)?ZSH=/ || t ~ /^ZSH_THEME=/ || t ~ /oh-my-zsh\.sh/ { next }
        { print }
    ' "$1"
}

# Does this zsh snippet parse? (false when zsh itself is missing)
zsh_parses() {
    command -v zsh &>/dev/null && printf '%s' "$1" | zsh -n 2>/dev/null
}

# Is every line of this snippet already in the repo's .zshrc?
zshrc_snippet_in_repo() {
    local line trimmed
    while IFS= read -r line; do
        trimmed="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        if ! grep -Fxq -e "$line" "$DOTFILES_DIR/.zshrc" 2>/dev/null && ! grep -Fxq -e "$trimmed" "$DOTFILES_DIR/.zshrc" 2>/dev/null; then
            return 1
        fi
    done <<< "${1%$'\n'}"
}

# Scenario B: ~/.zshrc is a regular file (e.g. the OMZ or distro template).
# Its code is split into complete statements with zsh's own parser (lines are
# joined until `zsh -n` accepts them), so if/for/function blocks stay whole.
# Statements already in the repo's .zshrc are dropped and the rest is carried
# over to ~/.zshrc.local. Anything that loads another prompt/framework (it would
# fight Starship) or never parses is copied commented-out for review instead.
rescue_physical_zshrc() {
    local target="$HOME/.zshrc"
    local framework_re='p10k|powerlevel|prezto|zinit|zplug|antigen|antidote|oh-my-posh|promptinit|zsh-config'

    if [ ! -f "$target" ] || [ -L "$target" ]; then
        return 0
    fi
    warn "Found existing physical file at $target (not a symlink)."

    local backup code line unit chunk="" active="" commented=""
    local -a units=()
    backup="$(backup_path "$target")"
    code="$(zshrc_custom_code "$target")"

    if [ -n "$code" ]; then
        while IFS= read -r line; do
            chunk+="$line"$'\n'
            if zsh_parses "$chunk"; then
                units+=("$chunk")
                chunk=""
            fi
        done <<< "$code"
    fi
    if [ -n "$chunk" ]; then
        units+=("$chunk")
    fi

    for unit in ${units[@]+"${units[@]}"}; do
        if zshrc_snippet_in_repo "$unit"; then
            continue
        elif grep -Eiq "$framework_re" <<< "$unit" || ! zsh_parses "$unit"; then
            commented+="$(sed 's/^/# /' <<< "${unit%$'\n'}")"$'\n'
        else
            active+="$unit"
        fi
    done

    if grep -Eq '^[[:space:]]*(ZSH_THEME=|plugins=\()' "$target"; then
        info "Skipping Oh My Zsh setup lines (ZSH_THEME, plugins, source); configsh's .zshrc manages them."
        echo -e "    ${BLUE}↳ Your previous plugin list stays available in $backup${RESET}"
    fi

    if [ -z "$active$commented" ]; then
        success "No custom settings to carry over from $target"
    else
        local review_note="# Commented out for review (loads another prompt/framework, or doesn't parse):"
        info "Detected custom or installer configuration in existing ~/.zshrc:"
        echo -e "${CYAN}----------------------------------------------------------------${RESET}"
        echo -n "$active"
        if [ -n "$commented" ]; then
            echo -e "${YELLOW}${review_note}${RESET}"
            echo -n "$commented"
        fi
        echo -e "${CYAN}----------------------------------------------------------------${RESET}"

        local migrate_choice="y"
        if [ "${ASSUME_YES:-false}" != true ]; then
            read -r -p "Add these lines to ~/.zshrc.local before symlinking? [Y/n] " migrate_choice || migrate_choice="y"
            migrate_choice="${migrate_choice:-y}"
        fi

        if [[ "$migrate_choice" =~ ^[Yy]$ ]]; then
            {
                echo ""
                echo "# -----------------------------------------------------------------------------"
                echo "# Rescued from physical ~/.zshrc on $(date '+%Y-%m-%d %H:%M:%S') (original: $backup)"
                echo "# -----------------------------------------------------------------------------"
                echo -n "$active"
                if [ -n "$commented" ]; then
                    echo "$review_note"
                    echo -n "$commented"
                fi
            } >> "$HOME/.zshrc.local"
            chmod 600 "$HOME/.zshrc.local"
            success "Added custom configuration to ~/.zshrc.local"
        fi
    fi

    warn "Backing up physical $target to $backup"
    mv "$target" "$backup"
}

# Run zshrc rescue checks for Scenarios A & B
rescue_zshrc_installer_changes
rescue_physical_zshrc

# Link .zshrc
link_file "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

# Link starship.toml
link_file "$DOTFILES_DIR/.config/starship.toml" "$HOME/.config/starship.toml"

# Link Fastfetch config (only if fastfetch is installed or configured)
if command -v fastfetch &>/dev/null || [ -f "$DOTFILES_DIR/.config/fastfetch/config.jsonc" ]; then
    link_file "$DOTFILES_DIR/.config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
fi

# Link Ghostty config (only if Ghostty is installed or previously configured)
if command -v ghostty &>/dev/null || [ -d "/Applications/Ghostty.app" ] || [ -f "/usr/lib/systemd/user/app-com.mitchellh.ghostty.service" ] || [ -L "$HOME/.config/ghostty/config" ]; then
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

# Ensure custom Oh My Zsh plugins are present if Oh My Zsh is installed
if [ -d "$HOME/.oh-my-zsh" ]; then
    CUSTOM_PLUGINS_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    mkdir -p "$CUSTOM_PLUGINS_DIR"

    # Remove dangling plugin symlinks if previously pointed to removed paths
    for _dead_plugin in fzf-tab zsh-autosuggestions zsh-syntax-highlighting; do
        if [ -L "$CUSTOM_PLUGINS_DIR/$_dead_plugin" ] && [ ! -e "$CUSTOM_PLUGINS_DIR/$_dead_plugin" ]; then
            rm -f "$CUSTOM_PLUGINS_DIR/$_dead_plugin"
        fi
    done
    unset _dead_plugin

    if [ ! -d "$CUSTOM_PLUGINS_DIR/fzf-tab" ]; then
        info "Installing fzf-tab plugin for Oh My Zsh..."
        if git clone --quiet https://github.com/Aloxaf/fzf-tab "$CUSTOM_PLUGINS_DIR/fzf-tab" 2>/dev/null; then
            success "Installed fzf-tab plugin"
        else
            warn "Failed to clone fzf-tab plugin (check internet connection)"
        fi
    fi
    if [ ! -d "$CUSTOM_PLUGINS_DIR/zsh-autosuggestions" ]; then
        if [ -d "/usr/share/zsh/plugins/zsh-autosuggestions" ]; then
            info "Linking system zsh-autosuggestions plugin for Oh My Zsh..."
            ln -sfn "/usr/share/zsh/plugins/zsh-autosuggestions" "$CUSTOM_PLUGINS_DIR/zsh-autosuggestions" && success "Linked zsh-autosuggestions plugin"
        elif [ -f "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
            info "Configuring system zsh-autosuggestions plugin for Oh My Zsh..."
            mkdir -p "$CUSTOM_PLUGINS_DIR/zsh-autosuggestions"
            ln -sfn "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" "$CUSTOM_PLUGINS_DIR/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh" && success "Linked zsh-autosuggestions plugin"
        elif [ -f "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
            info "Configuring Homebrew zsh-autosuggestions plugin for Oh My Zsh..."
            mkdir -p "$CUSTOM_PLUGINS_DIR/zsh-autosuggestions"
            ln -sfn "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" "$CUSTOM_PLUGINS_DIR/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh" && success "Linked zsh-autosuggestions plugin"
        elif [ -f "/home/linuxbrew/.linuxbrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
            info "Configuring Linuxbrew zsh-autosuggestions plugin for Oh My Zsh..."
            mkdir -p "$CUSTOM_PLUGINS_DIR/zsh-autosuggestions"
            ln -sfn "/home/linuxbrew/.linuxbrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" "$CUSTOM_PLUGINS_DIR/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh" && success "Linked zsh-autosuggestions plugin"
        elif [ -f "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
            info "Configuring Homebrew zsh-autosuggestions plugin for Oh My Zsh..."
            mkdir -p "$CUSTOM_PLUGINS_DIR/zsh-autosuggestions"
            ln -sfn "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh" "$CUSTOM_PLUGINS_DIR/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh" && success "Linked zsh-autosuggestions plugin"
        else
            info "Installing zsh-autosuggestions plugin for Oh My Zsh..."
            git clone --quiet https://github.com/zsh-users/zsh-autosuggestions "$CUSTOM_PLUGINS_DIR/zsh-autosuggestions" 2>/dev/null && success "Installed zsh-autosuggestions plugin" || true
        fi
    fi
    if [ ! -d "$CUSTOM_PLUGINS_DIR/zsh-syntax-highlighting" ]; then
        if [ -d "/usr/share/zsh/plugins/zsh-syntax-highlighting" ]; then
            info "Linking system zsh-syntax-highlighting plugin for Oh My Zsh..."
            ln -sfn "/usr/share/zsh/plugins/zsh-syntax-highlighting" "$CUSTOM_PLUGINS_DIR/zsh-syntax-highlighting" && success "Linked zsh-syntax-highlighting plugin"
        elif [ -f "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
            info "Configuring system zsh-syntax-highlighting plugin for Oh My Zsh..."
            mkdir -p "$CUSTOM_PLUGINS_DIR/zsh-syntax-highlighting"
            ln -sfn "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" "$CUSTOM_PLUGINS_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh" && success "Linked zsh-syntax-highlighting plugin"
        elif [ -f "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
            info "Configuring Homebrew zsh-syntax-highlighting plugin for Oh My Zsh..."
            mkdir -p "$CUSTOM_PLUGINS_DIR/zsh-syntax-highlighting"
            ln -sfn "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" "$CUSTOM_PLUGINS_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh" && success "Linked zsh-syntax-highlighting plugin"
        elif [ -f "/home/linuxbrew/.linuxbrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
            info "Configuring Linuxbrew zsh-syntax-highlighting plugin for Oh My Zsh..."
            mkdir -p "$CUSTOM_PLUGINS_DIR/zsh-syntax-highlighting"
            ln -sfn "/home/linuxbrew/.linuxbrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" "$CUSTOM_PLUGINS_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh" && success "Linked zsh-syntax-highlighting plugin"
        elif [ -f "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
            info "Configuring Homebrew zsh-syntax-highlighting plugin for Oh My Zsh..."
            mkdir -p "$CUSTOM_PLUGINS_DIR/zsh-syntax-highlighting"
            ln -sfn "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" "$CUSTOM_PLUGINS_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh" && success "Linked zsh-syntax-highlighting plugin"
        else
            info "Installing zsh-syntax-highlighting plugin for Oh My Zsh..."
            git clone --quiet https://github.com/zsh-users/zsh-syntax-highlighting.git "$CUSTOM_PLUGINS_DIR/zsh-syntax-highlighting" 2>/dev/null && success "Installed zsh-syntax-highlighting plugin" || true
        fi
    fi
fi

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
