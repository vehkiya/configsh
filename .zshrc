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


# Cross-platform plugins
plugins=(
  git
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

# Vault & OpenBao completion / compatibility
if command -v bao &>/dev/null; then
  complete -o nospace -C bao bao 2>/dev/null || true
  command -v vault &>/dev/null || alias vault="bao"
fi
if command -v vault &>/dev/null; then
  complete -o nospace -C vault vault 2>/dev/null || true
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
