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

# fssh: Interactive SSH host picker with live config preview
if command -v fzf &>/dev/null; then
  fssh() {
    local query=""
    local -a ssh_args=()

    # Pre-populate search query if first argument is not a flag
    if [[ -n "${1:-}" && "${1:0:1}" != "-" ]]; then
      query="$1"
      shift
    fi
    ssh_args=("$@")

    local config_files=()
    [[ -f "$HOME/.ssh/config" ]] && config_files+=("$HOME/.ssh/config")
    for d in "$HOME/.ssh/config.d" "$HOME/.ssh/conf.d"; do
      if [[ -d "$d" ]]; then
        for f in "$d"/*(N); do
          [[ -f "$f" ]] && config_files+=("$f")
        done
      fi
    done

    if [[ ${#config_files[@]} -eq 0 ]]; then
      echo "fssh: No SSH config files found in ~/.ssh/" >&2
      return 1
    fi

    local host
    host=$(
      awk '
        tolower($1) == "host" {
          for (i = 2; i <= NF; i++) {
            if ($i !~ /[*?!]/) print $i
          }
        }
      ' "${config_files[@]}" 2>/dev/null | sort -u | fzf \
        --prompt="SSH > " \
        --query="$query" \
        --height=60% \
        --reverse \
        --preview='ssh -G {} 2>/dev/null | grep -E "^(user|hostname|port|identityfile|proxyjump) " | awk "{printf \"%-14s %s\n\", \$1 \":\", \$2}"' \
        --preview-window="right,50%,border-left,<80(down,50%)"
    )

    if [[ -n "$host" ]]; then
      echo "Connecting to $host..."
      ssh "${ssh_args[@]}" "$host"
    fi
  }
fi

# ssh-add-host: Interactively configure and add a host to ~/.ssh/config
ssh-add-host() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat << 'EOF'
Usage: ssh-add-host [user@host[:port]] [alias]

Interactively configure and save an SSH host block to ~/.ssh/config.

Arguments:
  user@host[:port]   Target connection string (optional)
  alias              Custom nickname/alias for ~/.ssh/config (optional)

Features:
  - Supports SSH key auth, password-only auth, or standard fallback
  - Detects existing keys in ~/.ssh, offers new key generation, or ssh-copy-id
  - Hardens password-only hosts with 'PubkeyAuthentication no' to prevent agent lockouts
  - Automatically places host definitions before wildcard 'Host *' blocks
  - Verifies and maintains strict 0600 permissions on ~/.ssh/config
  - Offers immediate connection testing upon completion

Aliases: fssh-add, add-ssh-host
EOF
    return 0
  fi

  local input="${1:-}"
  local alias="${2:-}"
  local user="" hostname="" port="22"

  if [[ "$input" =~ ^([^@]+)@([^:]+):([0-9]+)$ ]]; then
    user="${match[1]:-${BASH_REMATCH[1]}}"
    hostname="${match[2]:-${BASH_REMATCH[2]}}"
    port="${match[3]:-${BASH_REMATCH[3]}}"
  elif [[ "$input" =~ ^([^@]+)@(.+)$ ]]; then
    user="${match[1]:-${BASH_REMATCH[1]}}"
    hostname="${match[2]:-${BASH_REMATCH[2]}}"
    port="22"
  elif [[ "$input" =~ ^([^:]+):([0-9]+)$ ]]; then
    user="${USER:-$(whoami)}"
    hostname="${match[1]:-${BASH_REMATCH[1]}}"
    port="${match[2]:-${BASH_REMATCH[2]}}"
  elif [[ -n "$input" ]]; then
    user="${USER:-$(whoami)}"
    hostname="$input"
    port="22"
  fi

  if [[ -z "$hostname" ]]; then
    printf "HostName (FQDN or IP address): "
    read -r hostname
    if [[ -z "$hostname" ]]; then
      echo "HostName is required." >&2
      return 1
    fi
  fi

  if [[ -z "$user" ]]; then
    local default_user="${USER:-$(whoami)}"
    printf "User [%s]: " "$default_user"
    read -r user
    user="${user:-$default_user}"
  fi

  if [[ -z "${1:-}" ]]; then
    printf "Port [22]: "
    read -r input_port
    port="${input_port:-22}"
  fi

  if [[ -z "$alias" ]]; then
    printf "Host alias / nickname [%s]: " "$hostname"
    read -r alias
    alias="${alias:-$hostname}"
  fi

  echo ""
  echo "Authentication method for '$alias':"
  echo "  1) SSH Key (IdentityFile)"
  echo "  2) Password only (disables pubkey & agent keys)"
  echo "  3) Standard / Default (agent keys with password fallback)"
  printf "Select [1-3] (default: 1): "
  read -r auth_choice
  auth_choice="${auth_choice:-1}"

  local key_path=""
  if [[ "$auth_choice" == "1" ]]; then
    local -a found_keys=()
    for k in "$HOME"/.ssh/id_*(N) "$HOME"/.ssh/*.pem(N); do
      [[ "$k" == *.pub || "$k" == *known_hosts* || "$k" == *authorized_keys* || "$k" == *allowed_signers* ]] && continue
      [[ -f "$k" ]] && found_keys+=("$k")
    done

    if [[ ${#found_keys[@]} -gt 0 ]]; then
      echo ""
      echo "Available SSH keys in ~/.ssh:"
      local idx=1
      for k in "${found_keys[@]}"; do
        echo "  $idx) ${k#$HOME/}"
        ((idx++))
      done
      echo "  c) Enter custom key path"
      echo "  n) Generate new Ed25519 key"
      printf "Select key [1]: "
      read -r key_pick
      key_pick="${key_pick:-1}"

      if [[ "$key_pick" =~ ^[0-9]+$ ]] && [[ "$key_pick" -ge 1 && "$key_pick" -le ${#found_keys[@]} ]]; then
        key_path="${found_keys[$key_pick]}"
      elif [[ "$key_pick" == [cC]* ]]; then
        printf "Path to private key: "
        read -r key_path
        key_path="${key_path/#\~/$HOME}"
      elif [[ "$key_pick" == [nN]* ]]; then
        local def_key="$HOME/.ssh/id_ed25519_${alias%% *}"
        printf "New key path [%s]: " "${def_key#$HOME/}"
        read -r gen_path
        gen_path="${gen_path:-$def_key}"
        gen_path="${gen_path/#\~/$HOME}"
        ssh-keygen -t ed25519 -C "${user}@${hostname}" -f "$gen_path"
        key_path="$gen_path"
      else
        key_path="${found_keys[1]}"
      fi
    else
      echo ""
      echo "No SSH keys found in ~/.ssh."
      echo "  1) Enter existing key path"
      echo "  2) Generate new Ed25519 key"
      printf "Choose [1-2] (default: 2): "
      read -r no_key_choice
      if [[ "$no_key_choice" == "1" ]]; then
        printf "Path to private key: "
        read -r key_path
        key_path="${key_path/#\~/$HOME}"
      else
        local def_key="$HOME/.ssh/id_ed25519_${alias%% *}"
        printf "New key path [%s]: " "${def_key#$HOME/}"
        read -r gen_path
        gen_path="${gen_path:-$def_key}"
        gen_path="${gen_path/#\~/$HOME}"
        ssh-keygen -t ed25519 -C "${user}@${hostname}" -f "$gen_path"
        key_path="$gen_path"
      fi
    fi

    if [[ -n "$key_path" && ! -f "$key_path" ]]; then
      echo "Warning: Key file '$key_path' does not exist." >&2
    fi

    local pub_key="${key_path}.pub"
    if [[ -f "$pub_key" ]]; then
      printf "Copy public key to %s@%s with ssh-copy-id? [y/N]: " "$user" "$hostname"
      read -r copy_confirm
      if [[ "$copy_confirm" == [yY]* ]]; then
        local port_flag=()
        [[ "$port" != "22" ]] && port_flag=(-p "$port")
        ssh-copy-id "${port_flag[@]}" -i "$pub_key" "${user}@${hostname}"
      fi
    fi
  fi

  local entry="Host $alias"
  entry+=$'\n'"    HostName $hostname"
  [[ -n "$user" ]] && entry+=$'\n'"    User $user"
  [[ "$port" != "22" ]] && entry+=$'\n'"    Port $port"

  if [[ "$auth_choice" == "1" && -n "$key_path" ]]; then
    local display_key="${key_path/#$HOME/~}"
    entry+=$'\n'"    IdentityFile $display_key"
    entry+=$'\n'"    IdentitiesOnly yes"
  elif [[ "$auth_choice" == "2" ]]; then
    entry+=$'\n'"    PubkeyAuthentication no"
    entry+=$'\n'"    PreferredAuthentications password,keyboard-interactive"
  fi

  local ssh_dir="$HOME/.ssh"
  local ssh_config="$ssh_dir/config"
  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"
  touch "$ssh_config"
  chmod 600 "$ssh_config"

  local exists=0
  for a in ${(z)alias}; do
    if awk -v a="$a" 'tolower($1) == "host" { for (i=2; i<=NF; i++) if ($i == a) exit 0 } END { exit 1 }' "$ssh_config" 2>/dev/null; then
      exists=1
      break
    fi
  done

  if [[ $exists -eq 1 ]]; then
    printf "\nWarning: Host alias in '%s' is already defined in %s.\n" "$alias" "$ssh_config"
    printf "Overwrite existing host block? [y/N]: "
    read -r overwrite_reply
    if [[ "$overwrite_reply" != [yY]* ]]; then
      echo "Aborted."
      return 1
    fi

    local tmp_clean
    tmp_clean=$(mktemp "$ssh_dir/config.tmp.XXXXXX")
    awk -v target="$alias" '
      BEGIN {
        split(target, targets, /[ \t]+/)
        for (t in targets) target_map[targets[t]] = 1
      }
      tolower($1) == "host" || tolower($1) == "match" {
        skip = 0
        if (tolower($1) == "host") {
          for (i = 2; i <= NF; i++) {
            if ($i in target_map) { skip = 1; break }
          }
        }
      }
      !skip { print }
    ' "$ssh_config" > "$tmp_clean" && mv "$tmp_clean" "$ssh_config"
    chmod 600 "$ssh_config"
  fi

  local tmp_file
  tmp_file=$(mktemp "$ssh_dir/config.tmp.XXXXXX")
  awk -v block="$entry" '
    !inserted && /^#/ {
      comment_buf = (comment_buf == "" ? $0 : comment_buf "\n" $0)
      next
    }
    !inserted && /^Host[[:space:]]+\*/ {
      print block
      print ""
      if (comment_buf != "") print comment_buf
      print $0
      inserted = 1
      comment_buf = ""
      next
    }
    {
      if (comment_buf != "") {
        print comment_buf
        comment_buf = ""
      }
      print $0
    }
    END {
      if (!inserted) {
        if (NR > 0) print ""
        if (comment_buf != "") print comment_buf
        print block
      }
    }
  ' "$ssh_config" > "$tmp_file" && mv "$tmp_file" "$ssh_config"
  chmod 600 "$ssh_config"

  echo ""
  echo "Successfully added to $ssh_config:"
  echo "----------------------------------------"
  echo "$entry"
  echo "----------------------------------------"
  echo ""

  local connect_alias="${alias%% *}"
  printf "Connect to '%s' now? [Y/n]: " "$connect_alias"
  read -r connect_reply
  if [[ -z "$connect_reply" || "$connect_reply" == [yY]* ]]; then
    ssh "$connect_alias"
  fi
}

alias fssh-add="ssh-add-host"
alias add-ssh-host="ssh-add-host"
