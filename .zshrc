# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Theme: Disabled because Starship manages the prompt
ZSH_THEME=""

# Oh My Zsh Update settings
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 3

# Disable command auto-correction
ENABLE_CORRECTION="false"

# History security & privacy
HISTSIZE=10000
SAVEHIST=10000
HISTFILE="$HOME/.zsh_history"
setopt HIST_IGNORE_SPACE         # Prefix command with a space to prevent writing to history
setopt HIST_IGNORE_DUPS          # Don't record duplicate commands
setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks
setopt SHARE_HISTORY             # Share history across sessions


# Git auto-fetch interval (default: 30 minutes = 1800 seconds)
export GIT_AUTO_FETCH_INTERVAL="${GIT_AUTO_FETCH_INTERVAL:-1800}"

# Cross-platform plugins
plugins=(
  git
  git-auto-fetch
  rsync
  golang
  docker
  docker-compose
  kubectl
  kubectx
  helm
  node
  npm
  nvm
  emoji-clock
  vault
  pass
  fzf-tab
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# OS-specific plugins
if [[ "$(uname)" == "Darwin" ]]; then
  plugins+=(macos)
elif [[ "$(uname)" == "Linux" ]]; then
  command -v pacman &>/dev/null && plugins+=(archlinux)
fi

# Load Oh My Zsh if installed
[[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# Language environment
export LANG="en_US.UTF-8"

# GPG & SSH Agent Environment (OS Keychain integration)
export GPG_TTY="${GPG_TTY:-$(tty 2>/dev/null || echo '')}"

# SSH Agent Socket (systemd user socket on Linux, launchd on macOS)
if [[ -z "$SSH_AUTH_SOCK" ]]; then
  if [[ -S "${XDG_RUNTIME_DIR:-/run/user/$UID}/ssh-agent.socket" ]]; then
    export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$UID}/ssh-agent.socket"
  elif [[ -S "${XDG_RUNTIME_DIR:-/run/user/$UID}/gcr/ssh" ]]; then
    export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$UID}/gcr/ssh"
  fi
fi

# SSH Askpass (GUI password prompt for KWallet / Keyring)
if [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
  if command -v ksshaskpass &>/dev/null; then
    export SSH_ASKPASS="$(command -v ksshaskpass)"
    export SSH_ASKPASS_REQUIRE="prefer"
  fi
fi

# Editor configuration
if [[ -n "$SSH_CONNECTION" ]]; then
  export EDITOR="vim"
elif command -v nvim &>/dev/null; then
  export EDITOR="nvim"
fi

if command -v code &>/dev/null; then
  export VISUAL="code --wait"
fi

# Aliases
if command -v eza &>/dev/null; then
  alias ls="eza --icons --group-directories-first"
  alias ll="eza -al --icons --group-directories-first --git"
else
  alias ls="ls --color=auto"
  alias ll="ls -la"
fi

alias k="kubectl"
alias kx="kubectx"
alias kn="kubens"
alias d="docker"
alias dc="docker-compose"
alias v="vault"
alias b="bao"
alias p="pass"

# Vault & OpenBao completion / bidirectional compatibility
if command -v bao &>/dev/null && ! command -v vault &>/dev/null; then
  alias vault="bao"
elif command -v vault &>/dev/null && ! command -v bao &>/dev/null; then
  alias bao="vault"
fi

if command -v bao &>/dev/null; then
  complete -o nospace -C bao bao 2>/dev/null || true
  complete -o nospace -C bao vault 2>/dev/null || true
fi
if command -v vault &>/dev/null; then
  complete -o nospace -C vault vault 2>/dev/null || true
  complete -o nospace -C vault bao 2>/dev/null || true
fi

# Homebrew environment (supports Apple Silicon macOS, Intel macOS, and Linuxbrew)
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
elif [[ -x "/usr/local/bin/brew" ]]; then
  eval "$(/usr/local/bin/brew shellenv zsh)"
elif [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
fi

# Tool initializations (graceful execution if installed)
command -v fnm &>/dev/null && eval "$(fnm env --use-on-cd 2>/dev/null || fnm env)"
command -v fzf &>/dev/null && eval "$(fzf --zsh)"
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"
[[ -f "$HOME/.config/direnv/direnvrc" ]] && source "$HOME/.config/direnv/direnvrc"
command -v starship &>/dev/null && eval "$(starship init zsh)"

# User local bin paths (portable across macOS and Linux)
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

# Bun (if installed)
export BUN_INSTALL="$HOME/.bun"
[[ -d "$BUN_INSTALL/bin" ]] && export PATH="$BUN_INSTALL/bin:$PATH"
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"

# SDKMAN (if installed - must stay near end of shell configuration)
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# Local / Machine-specific secrets & overrides (never committed to git)
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# Zoxide navigation (smarter cd command - set ZOXIDE_REPLACE_CD=true in ~/.zshrc.local to alias 'cd')
if command -v zoxide &>/dev/null; then
  if [[ "${ZOXIDE_REPLACE_CD:-false}" == "true" ]]; then
    eval "$(zoxide init zsh --cmd cd)"
  else
    eval "$(zoxide init zsh)"
  fi
fi

# Yazi terminal file manager (shell cwd sync via 'y')
if command -v yazi &>/dev/null; then
  function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
      builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
  }
fi

# Bat / Batcat compatibility (Debian/Ubuntu)
if ! command -v bat &>/dev/null && command -v batcat &>/dev/null; then
  alias bat="batcat"
fi

# Fzf-Tab completion styling & rich previews (eza for dirs, bat for files)
if [[ " ${plugins[*]} " =~ " fzf-tab " ]]; then
  # Disable sort when completing git checkout
  zstyle ':completion:*:git-checkout:*' sort false
  # Force zsh not to show completion menu, allowing fzf-tab to capture it
  zstyle ':completion:*' menu no
  # Enable colorized completion lists
  zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
  # Custom descriptions format
  zstyle ':completion:*:descriptions' format '[%d]'

  # Preview directory contents with eza when completing cd / z
  if command -v eza &>/dev/null; then
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
    zstyle ':fzf-tab:complete:z:*' fzf-preview 'eza -1 --color=always $realpath'
  fi

  # Preview file contents with bat when completing file arguments
  if command -v bat &>/dev/null; then
    zstyle ':fzf-tab:complete:*:*' fzf-preview 'bat --style=numbers --color=always --line-range :500 $realpath 2>/dev/null || cat $realpath 2>/dev/null'
  elif command -v batcat &>/dev/null; then
    zstyle ':fzf-tab:complete:*:*' fzf-preview 'batcat --style=numbers --color=always --line-range :500 $realpath 2>/dev/null || cat $realpath 2>/dev/null'
  fi
fi

# fif: Interactive Find In Files (live ripgrep + fzf + bat preview)
if command -v rg &>/dev/null && command -v fzf &>/dev/null; then
  fif() {
    local bat_cmd="cat"
    command -v bat &>/dev/null && bat_cmd="bat --style=numbers --color=always --line-range :500"
    command -v batcat &>/dev/null && bat_cmd="batcat --style=numbers --color=always --line-range :500"

    rg --column --line-number --no-heading --color=always --smart-case "${*:-}" 2>/dev/null |
      fzf --ansi \
          --color "hl:-1:underline,hl+:-1:underline:reverse" \
          --delimiter : \
          --preview "$bat_cmd {1} --highlight-line {2}" \
          --preview-window "up,60%,border-bottom,+{2}+3/3,~3" \
          --bind "enter:become(${EDITOR:-vim} +{2} {1})"
  }
fi

# Terminal markdown reader & cheatsheet viewer
if command -v glow &>/dev/null; then
  cheatsheet() {
    local zshrc_target="${HOME}/.zshrc"
    local cs_file="${zshrc_target:A:h}/CHEATSHEET.md"
    if [[ ! -f "$cs_file" ]]; then
      for candidate in \
        "$HOME/projects/configsh/CHEATSHEET.md" \
        "$HOME/configsh/CHEATSHEET.md" \
        "$HOME/.config/configsh/CHEATSHEET.md" \
        "$HOME/.dotfiles/CHEATSHEET.md"; do
        if [[ -f "$candidate" ]]; then
          cs_file="$candidate"
          break
        fi
      done
    fi

    if [[ -f "$cs_file" ]]; then
      glow -s dark "$cs_file" "$@"
    else
      echo "Error: CHEATSHEET.md not found (tried ${cs_file})" >&2
      return 1
    fi
  }
  alias cs="cheatsheet"
fi


# sshx: TUI SSH Connection Manager & Host Adder (native compiled utility: ~/.local/bin/sshx)
alias fssh="sshx"


