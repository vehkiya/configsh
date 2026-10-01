# configsh

Cross-platform dotfiles and development environment configuration for **macOS** and **Linux**.

Designed for portability, clean aesthetics (Gruvbox Dark), and supply chain defense against user-space malware (such as npm postinstall RATs).

---

## 🚀 Quick Setup

On any new macOS or Linux machine:

```bash
git clone https://github.com/vehkiya/configsh.git ~/projects/configsh
cd ~/projects/configsh
./setup.sh
```

> [!NOTE]
> `./setup.sh` automatically checks for recommended packages and tools (via [`scripts/check-prerequisites.sh`](scripts/check-prerequisites.sh)). If any are missing, it provides platform-tailored installation commands (`brew`, `pacman`/`paru`, `apt`) and asks for confirmation before proceeding. Pass `-y` or `--yes` to proceed without prompting.

Restart your terminal or run:
```bash
source ~/.zshrc
```

> [!TIP]
> Check out the **[Command & Workflow Cheat Sheet](CHEATSHEET.md)** for all daily aliases, interactive search helpers (`fif`), directory jumping (`z`, `y`), and shortcuts!

---

## 📦 What's Included

* **[Ghostty](.config/ghostty/config.ghostty)** *(Optional - applied automatically only if installed)*:
  * Warm Gruvbox Dark aesthetic matching Starship.
  * Balanced window padding (12px) for Powerline capsules.
  * Native shell integration with OSC 133 prompt markers.
  * Ergonomic macOS Option key mapping (`macos-option-as-alt = left`, preserving Right Option for accents/symbols).
  * Systemd drop-in override for Linux to avoid `Type=notify-reload` race conditions.
* **[Starship](.config/starship.toml)**:
  * Fast, segmented Powerline prompt with pill capsules (`` ... ``).
  * Integrated command duration tracking (`$cmd_duration` for commands taking > 2s).
  * Directory icon substitutions (e.g. `~/projects` $\rightarrow$ `~/󰲋`).
  * Cross-platform OS detection (macOS, Arch, Ubuntu, etc.).
* **[Zsh](.zshrc)**:
  * Multi-architecture Homebrew support (Apple Silicon `/opt/homebrew`, Intel Mac `/usr/local`, Linux `/home/linuxbrew`).
  * OS-conditional Oh My Zsh plugins (`macos` on Darwin, `archlinux` on Arch).
  * Defensive tool initializations (`eza`, `fnm`, `fzf`, `direnv`, `starship`, `zoxide`, `yazi`).
  * Modern tab completion via **`fzf-tab`** with live previews (`eza` for directories, `bat` for files).
  * Interactive text search via **`fif`** (`ripgrep` + `fzf` + `bat` preview with direct editor jumping).
  * Interactive cheatsheet via **`cs`** / **`cheatsheet`** (terminal markdown reader with `glow`).
  * TUI SSH connection manager via **`sshx`** (`fssh` / `sshx add`: Bubble Tea host browser, Huh adder wizard, key discovery, `ssh-copy-id`).
  * History privacy (`HIST_IGNORE_SPACE` — commands starting with a space are never written to disk).
  * Secrets and tool completions (`vault`, `pass`, aliases `v`, `b`, `p`).
  * Local machine configuration integration (`~/.zshrc.local`).
* **[Direnv](.config/direnv/direnvrc)**:
  * Project-scoped environment switching.
  * Native helper functions `use_pass` and `use_vault` for loading secrets on-demand.

---

## 🔐 Secrets Management (Direnv + Pass + OpenBao)

To keep private keys and tokens out of global shell environments (protecting against environment scraping by untrusted dependencies), secrets are scoped to projects using **direnv** and encrypted backends.

### 1. Project-Scoped Secrets (`.envrc`)

In any project repository, create a `.envrc` (ignored by git):

```bash
# Example .envrc

# 1. Pull from local GPG-encrypted password store (pass)
use_pass ANTHROPIC_API_KEY dev/anthropic/api_key
use_pass CLOUDFLARE_API_TOKEN cloudflare/tokens/deploy

# 2. Pull from centralized OpenBao / Vault instance
use_vault DATABASE_URL secret/data/projects/my-app db_url
use_vault REDIS_PASSWORD secret/data/projects/my-app redis_auth
```

Then run `direnv allow`. Direnv will load the secrets into memory only when entering the project directory, and unload them when exiting.

### 2. Local Password Store (`pass`)
* Backed by GPG encryption and Git.
* Initialize on a new machine:
  ```bash
  pass init <YOUR_GPG_KEY_ID>
  ```
* Add secrets:
  ```bash
  pass insert dev/anthropic/api_key
  ```

### 3. OpenBao / Vault CLI
* Configure your vault address in `~/.zshrc.local`:
  ```bash
  export VAULT_ADDR="https://your-vault-host:8200"
  ```
* Authenticate:
  ```bash
  bao login  # or vault login
  ```
* Oh My Zsh includes tab completions and aliases:
  * `v` $\rightarrow$ `vault`
  * `b` $\rightarrow$ `bao`
  * `p` $\rightarrow$ `pass`

### 4. OS Keychain & Passphrase Remembering
Never get repeatedly prompted in the terminal for GPG or SSH passphrases:
* **GPG (`gpg-agent.conf`)**:
  * Configured with [`scripts/pinentry-wrapper.sh`](scripts/pinentry-wrapper.sh).
  * Automatically detects graphical sessions and uses native GUI pinentry (`pinentry-qt` with KWallet on KDE, `pinentry-gnome3` on GNOME, `pinentry-mac` with Keychain on macOS).
  * Offers a **"Save in password manager / Keychain"** checkbox so passphrases only need to be entered once.
  * Falls back to `pinentry-curses` in headless, remote SSH, or pure TTY sessions.
* **SSH & Git Signing (`~/.ssh/config`)**:
  * `AddKeysToAgent yes` automatically caches unlocked private keys in `ssh-agent`.
  * On Linux (KDE), `ksshaskpass` provides a native KWallet prompt to remember SSH passphrases.
  * On macOS, `UseKeychain yes` remembers keys in Apple Keychain.

---

## 🛡️ Security Baseline & Hardening

Running `./setup.sh` automatically enforces the following defenses:

1. **Permission Hardening (`chmod 700` & `600`)**:
   * Restricts credential directories (`~/.ssh`, `~/.aws`, `~/.kube`, `~/.talos`, `~/.docker`, `~/.password-store`, `~/.config/gh`) to owner-only (`700`).
   * Restricts private keys and config tokens (`id_*`, `credentials`, `config.json`, `mcp_config.json`) to `600`.
2. **Supply Chain Defense (ViteVenom / Malicious Scripts)**:
   * Sets `npm config set ignore-scripts true` globally. Prevents untrusted third-party npm packages from running arbitrary `postinstall` binaries or reverse shells during installation.
3. **SSH Key Audit**:
   * Scans all private keys in `~/.ssh/` and alerts if any key is stored unencrypted without a passphrase on disk.
4. **Zero Global Plaintext Secrets**:
   * No API keys, database credentials, or tokens are exported globally in `.zshrc` or `.zprofile`.

---

## 🔑 Machine-Specific Configuration (`~/.zshrc.local`)

Never commit private credentials or machine-specific endpoints to Git. For local environment variables, Vault endpoints, or work-specific aliases, add them to `~/.zshrc.local`:

```zsh
# ~/.zshrc.local (Ignored by Git, chmod 600)
export VAULT_ADDR="https://vault.internal.net:8200"
export WORK_VPN_ENDPOINT="vpn.example.com"
```

This file is automatically loaded at the end of `.zshrc` and is excluded from Git tracking via `.gitignore`.

