# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# PATH comes first so Oh My Zsh plugins and every 'command -v' check below can
# see Homebrew and ~/.local/bin tools (macOS doesn't put Homebrew on PATH itself)
typeset -U path PATH

# Homebrew environment (supports Apple Silicon macOS, Intel macOS, and Linuxbrew)
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
elif [[ -x "/usr/local/bin/brew" ]]; then
  eval "$(/usr/local/bin/brew shellenv zsh)"
elif [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
fi

# User local bin paths (portable across macOS and Linux)
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

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

# Language environment (preserve existing valid UTF-8 locale; fallback gracefully if ungenerated)
if [[ -z "$LANG" || "$LANG" == "C" || "$LANG" == "POSIX" ]]; then
  if locale -a 2>/dev/null | grep -qEi '^en_US\.utf-?8$'; then
    export LANG="en_US.UTF-8"
  elif locale -a 2>/dev/null | grep -qEi '^C\.utf-?8$'; then
    export LANG="C.UTF-8"
  elif [[ "$(uname)" == "Darwin" ]]; then
    export LANG="en_US.UTF-8"
  else
    export LANG="C.UTF-8"
  fi
fi

# GPG & SSH Agent Environment (OS Keychain integration)
# Always this shell's own terminal: a GPG_TTY inherited from a parent (tmux,
# nested shells) would make pinentry prompt on the wrong terminal
[[ -n "$TTY" ]] && export GPG_TTY="$TTY"
# Over SSH, ask pinentry-wrapper for a terminal prompt instead of a GUI one on
# the remote desktop (gpg-agent forwards PINENTRY_USER_DATA to pinentry)
[[ -n "$SSH_CONNECTION" ]] && export PINENTRY_USER_DATA="USE_TTY"

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
# Container aliases fall back to Podman when Docker isn't installed
if ! command -v docker &>/dev/null && command -v podman &>/dev/null; then
  alias d="podman"
  alias dc="podman compose"
else
  alias d="docker"
  alias dc="docker compose"
fi
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

# Tool initializations (graceful execution if installed)
command -v fnm &>/dev/null && eval "$(fnm env --use-on-cd 2>/dev/null || fnm env)"
if command -v fzf &>/dev/null; then
  if _fzf_init="$(fzf --zsh 2>/dev/null)"; then
    eval "$_fzf_init"
    unset _fzf_init
  else
    for _fzf_comp in \
      "/usr/share/doc/fzf/examples/completion.zsh" \
      "/usr/share/fzf/completion.zsh" \
      "/opt/homebrew/opt/fzf/shell/completion.zsh" \
      "/usr/local/opt/fzf/shell/completion.zsh" \
      "$HOME/.fzf/shell/completion.zsh"; do
      if [[ -f "$_fzf_comp" ]]; then
        source "$_fzf_comp"
        break
      fi
    done
    for _fzf_key in \
      "/usr/share/doc/fzf/examples/key-bindings.zsh" \
      "/usr/share/fzf/key-bindings.zsh" \
      "/opt/homebrew/opt/fzf/shell/key-bindings.zsh" \
      "/usr/local/opt/fzf/shell/key-bindings.zsh" \
      "$HOME/.fzf/shell/key-bindings.zsh"; do
      if [[ -f "$_fzf_key" ]]; then
        source "$_fzf_key"
        break
      fi
    done
    unset _fzf_comp _fzf_key
  fi
fi
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"
command -v starship &>/dev/null && eval "$(starship init zsh)"

# Bun (if installed)
export BUN_INSTALL="$HOME/.bun"
[[ -d "$BUN_INSTALL/bin" ]] && export PATH="$BUN_INSTALL/bin:$PATH"
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"

# SDKMAN (if installed - must stay near end of shell configuration)
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# Local / Machine-specific secrets & overrides (never committed to git)
# Sourced here rather than last so its PATH additions are visible to the tool
# checks below and it can set ZOXIDE_REPLACE_CD; definitions below override it
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
    local rg_cmd="rg --column --line-number --no-heading --color=always --smart-case --"
    local query="$*" initial="true"
    [[ -n "$query" ]] && initial="$rg_cmd ${(q)query} 2>/dev/null"

    local preview="cat {1}"
    if command -v bat &>/dev/null; then
      preview="bat --style=numbers --color=always --line-range :500 --highlight-line {2} {1}"
    elif command -v batcat &>/dev/null; then
      preview="batcat --style=numbers --color=always --line-range :500 --highlight-line {2} {1}"
    fi

    # ripgrep re-runs on every keystroke (fzf only displays its results); an
    # empty query lists nothing instead of every line under the current dir, and
    # regex errors from half-typed patterns are hidden instead of garbling fzf
    FZF_DEFAULT_COMMAND="$initial" \
      fzf --ansi --disabled --query "$query" \
          --bind "change:reload:sleep 0.1; [ -n {q} ] && $rg_cmd {q} 2>/dev/null || true" \
          --color "hl:-1:underline,hl+:-1:underline:reverse" \
          --delimiter : \
          --preview "$preview" \
          --preview-window "up,60%,border-bottom,+{2}+3/3,~3" \
          --bind "enter:execute([ -n {1} ] && ${EDITOR:-vim} +{2} {1})+abort"
  }
fi

# Terminal markdown reader & cheatsheet viewer
unalias cheatsheet 2>/dev/null || true
if command -v glow &>/dev/null; then
  function cheatsheet {
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
      local width="${COLUMNS:-$(tput cols 2>/dev/null || echo 120)}"
      glow -s dark -w "$width" "$cs_file" "$@"
    else
      echo "Error: CHEATSHEET.md not found (tried ${cs_file})" >&2
      return 1
    fi
  }
  alias cs="cheatsheet"
fi


# sshx: TUI SSH Connection Manager & Host Adder (native compiled utility: ~/.local/bin/sshx)
alias fssh="sshx"


