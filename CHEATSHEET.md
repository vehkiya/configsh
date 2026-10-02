# 🚀 Configsh Command & Workflow Cheat Sheet

A comprehensive reference for the tools, aliases, functions, keybindings, and shortcuts configured in this environment.

---

## ⚡ Quick Start: Muscle Memory Upgrades

Replace your old command-line habits with these faster, modern alternatives:

| Instead of... (Old Habit) | Use this instead! (The Better Version) | Why it's better |
| :--- | :--- | :--- |
| `grep -r "text" .` | **`fif`** *(or `fif "query"`)* | **Interactive live ripgrep search**. As you type, matches appear with a syntax-highlighted `bat` preview pane. Pressing <kbd>Enter</kbd> opens your `$EDITOR` directly at that file and line. |
| `grep` in PDFs / `.docx` / `.zip` | **`rga "text"`** | `ripgrep-all` searches inside binaries, documents, archives (`.zip`, `.tar.gz`), and SQLite databases. |
| `cd path/to/nested/folder` | **`z <folder>`** *(e.g. `z conf`)* | Jumps directly to any directory you've visited before without typing the full path. |
| `cd` when you forget the path | **`zi`** | Opens an interactive fuzzy picker of all your frequent directories via `fzf`. |
| Browsing folders with `cd` & `ls` | **`y`** | Opens the ultra-fast `yazi` file manager. When you exit, **your shell automatically `cd`s to that folder**. |
| `cat file.py` | **`bat file.py`** | Colorized syntax highlighting, line numbers, and Git modification markers. |
| `ls` or `ls -la` | **`ls`** / **`ll`** | Aliased to `eza` with Nerd Font file icons, human-readable sizes, and Git status columns. |
| Static, flat <kbd>Tab</kbd> completion | <kbd>Tab</kbd> | Powered by **`fzf-tab`**: opens a fuzzy search popup. Previews directories with `eza` and files with `bat` before you even select them. |
| Pressing <kbd>↑</kbd> repeatedly for history | <kbd>Ctrl</kbd> + <kbd>R</kbd> | Interactive fuzzy history search with instant filtering. |
| `kubectl ...` | **`k`** | Short alias (`k get pods`). |
| Switching K8s context / namespace | **`kx`** / **`kn`** | Interactive context and namespace switchers. |
| `docker` / `docker compose` | **`d`** / **`dc`** | Muscle-memory short aliases. |
| `pass show ...` | **`p`** | Fast secret lookup (`p github/token`). |
| Remembering SSH hostnames / IPs | **`sshx`** *(or `fssh`)* | Interactive TUI SSH connection manager. Browse, fuzzy-search, add (<kbd>a</kbd>), delete (<kbd>d</kbd>), or connect (<kbd>Enter</kbd>). |
| Always typing `ssh user@host...` | **`sshx add`** | Interactive Huh wizard to configure and save SSH hosts to `~/.ssh/config`. Supports key/password auth, key generation, and `ssh-copy-id`. |
| Forgetting shell shortcuts/aliases | **`cs`** *(or `cheatsheet`)* | Opens this entire cheatsheet in an interactive terminal pager using `glow`. |
| Typing commands with API keys/tokens | `<space>command` | Prefix with a **single space**; it will never be written to your shell history. |

---

## 🔍 1. Text Search & Inspection

| Command | Tool | Description |
| :--- | :--- | :--- |
| **`cs`** / **`cheatsheet`** | `glow` | **Interactive Cheatsheet**: Opens this document in a styled, searchable terminal pager with mouse scroll. |
| **`glow <file.md>`** | `glow` | Command-line markdown reader with GitHub styling, tables, syntax highlighting, and word-wrap. |
| **`fif [query]`** | `rg` + `fzf` + `bat` | **Interactive Find In Files**: Live ripgrep search with syntax-highlighted preview. Pressing <kbd>Enter</kbd> opens `$EDITOR` directly at the matched line. |
| **`rg <pattern>`** | `ripgrep` | Ultra-fast recursive regex search across project files (honors `.gitignore`). |
| **`rga <pattern>`** | `ripgrep-all` | Ripgrep adapter for searching text inside PDFs, Word docs (`.docx`), E-books, archives (`.zip`, `.tar.gz`), and SQLite databases. |
| **`bat <file>`** | `bat` | Cat clone with syntax highlighting, line numbers, git change indicators, and paging. Aliased to `batcat` on Debian/Ubuntu systems automatically. |

---

## 📂 2. Navigation, Directory Jumping & Completion

| Command / Keybinding | Tool | Description |
| :--- | :--- | :--- |
| **`z <query>`** | `zoxide` | Smart jump: Navigates to directory matching query (e.g. `z doc` $\rightarrow$ `~/documents`). |
| **`zi`** | `zoxide` + `fzf` | Interactive directory jumper using an `fzf` fuzzy menu. |
| **`y [path]`** | `yazi` | Terminal file manager with automatic working directory synchronization on exit. |
| **`sshx [alias]`** | `sshx` | **TUI SSH Connection Manager** (`fssh`): Interactive Bubble Tea browser for all SSH hosts. Connect (<kbd>Enter</kbd>), search (<kbd>/</kbd>), add (<kbd>a</kbd>), delete (<kbd>d</kbd>), copy key (<kbd>c</kbd>), or edit (<kbd>e</kbd>). |
| **`sshx add [target] [alias]`** | `sshx` | **Interactive SSH Host Adder**: Huh wizard to configure hosts, keys, and password auth before `Host *`. |
| <kbd>Tab</kbd> | `fzf-tab` | Interactive completion menu: fuzzy-matches completion candidates with live directory (`eza`) and file (`bat`) previews. |
| <kbd>Ctrl</kbd> + <kbd>R</kbd> | `fzf` | Interactive command history search with fuzzy filtering. |
| <kbd>Ctrl</kbd> + <kbd>T</kbd> | `fzf` | Interactive file finder; pastes selected file path into the current command line. |
| <kbd>Alt</kbd> + <kbd>C</kbd> | `fzf` | Interactive directory finder; immediately `cd`s into the selected directory. |

---

## 📁 3. File Listing & Core Utilities

| Command | Tool | Description |
| :--- | :--- | :--- |
| **`ls`** | `eza` | `eza --icons --group-directories-first` (modern, colorized, iconified file listing). |
| **`ll`** | `eza` | `eza -al --icons --group-directories-first --git` (long listing with permissions, file sizes, and Git status indicators). |

---

## ☸️ 4. Containers, Cloud & Kubernetes

| Alias / Command | Full Command | Description |
| :--- | :--- | :--- |
| **`k`** | `kubectl` | Kubernetes CLI |
| **`kx`** | `kubectx` | Interactive Kubernetes cluster context switcher |
| **`kn`** | `kubens` | Interactive Kubernetes namespace switcher |
| **`k9s`** | `k9s` | Fullscreen curses-based terminal UI for Kubernetes |
| **`d`** | `docker` | Docker CLI |
| **`dc`** | `docker compose` | Docker Compose CLI (Compose V2) |
| **`colima start`** | `colima` | Start lightweight macOS container VM (`--vm-type=vz --vz-rosetta`) |
| **`colima stop`** | `colima` | Stop container VM and instantly free memory on macOS |
| **`colima status`** | `colima` | Check macOS container VM status and resource usage |
| **`talosctl`** | `talosctl` | Talos Linux management CLI |
| **`kubeconform`** | `kubeconform` | High-speed Kubernetes manifest validator (offline JSON schema validation) |
| **`yamllint`** | `yamllint` | YAML linter for syntax and schema verification |
| **`yq`** / **`jq`** | `yq` / `jq` | Portable YAML and JSON command-line stream processors |

---

## 🔐 5. Secrets, Vault & Passwords

| Command / Helper | Backend | Description |
| :--- | :--- | :--- |
| **`p`** | `pass` | Password manager CLI (e.g. `p email/gmail`) |
| **`v`** / **`vault`** | OpenBao / Vault | HashiCorp Vault CLI (bidirectionally aliased to `bao` if OpenBao is installed) |
| **`b`** / **`bao`** | OpenBao | OpenBao CLI (bidirectionally aliased to `vault` with shell completions) |
| **`use_pass VAR path`** | `.envrc` + `direnv` | Injects secret from `pass` into `$VAR` scoped only to the current directory. |
| **`use_vault VAR path [field]`** | `.envrc` + `direnv` | Injects secret from Vault/OpenBao into `$VAR` scoped only to the current directory. |
| **`pinentry-wrapper`** | GPG | Adaptive pinentry that routes to KWallet (`pinentry-qt`), macOS Keychain (`pinentry-mac`), or curses in terminal. |

---

## 🛡️ 6. Shell, Privacy & Terminal Behavior

| Feature | Trigger / Shortcut | Description |
| :--- | :--- | :--- |
| **History Privacy** | `<space><command>` | Any command typed with a leading space is **never** written to `~/.zsh_history` (`HIST_IGNORE_SPACE`). |
| **Ghost Suggestions** | <kbd>→</kbd> or <kbd>End</kbd> | `zsh-autosuggestions` predicts commands based on history; tap Right Arrow to accept. |
| **Syntax Highlighting** | Real-time | `zsh-syntax-highlighting` marks valid commands **green** and mistyped/invalid commands **red**. |
| **Git Auto Fetch** | Background (every 30m) | Silently runs `git fetch` on repos in the background so prompt ahead/behind markers (`⇡1 ⇣2`) stay current. |
| **SSH Key Agent** | Automatic | Private keys are auto-cached on first use via `AddKeysToAgent yes`. |
| **Ghostty (Optional)** | Terminal Emulator | Configured with Gruvbox Dark aesthetic, 12px padding, and Wayland/macOS support. Applied conditionally only if installed. |
| **Starship** | Shell Prompt | Fast Powerline prompt with directory icons and duration tracking for commands taking $>2$s. |

---

## ⚙️ 7. System Setup & Diagnostics

| Command | File / Script | Description |
| :--- | :--- | :--- |
| **`./setup.sh`** | [`setup.sh`](setup.sh) | Idempotent setup: verifies tools, creates symlinks, hardens permissions (`700`/`600`), and configures services. |
| **`./setup.sh --verify`** | [`scripts/doctor.sh`](scripts/doctor.sh) | 44-point read-only health check: checks symlink integrity, Git repo tamper detection, agent sockets, and permissions. |
| **`~/.zshrc.local`** | Local overrides | Machine-specific private overrides and secrets (untracked by Git, secured at `chmod 600`). |
