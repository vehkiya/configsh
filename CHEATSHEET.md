# 🚀 Command & Workflow Cheat Sheet

> Run **`cs`** (or **`cs -p`** to view with pager) anytime to open this reference.

---

## 📂 Files & Directories

* **`yazi`** / **`y [path]`** — **TUI File Manager**: Dual-pane file explorer (`y` auto-`cd`s shell on exit)
* **`z <query>`** — Smart jump to visited directory by partial name (`zoxide`, e.g. `z conf`)
* **`zi`** — Interactive fuzzy directory picker (`zoxide` + `fzf`)
* **`ls`** — Modern directory listing with file icons and directory grouping (`eza`)
* **`ll`** — Detailed long listing with Git status, permissions, and human sizes (`eza`)
* **`la`** — List all files including hidden entries (`eza`)
* **`lt`** — 2-level tree view with icons (`eza`)
* <kbd>Ctrl</kbd> + <kbd>T</kbd> — Fuzzy find file path and insert it into current command line (`fzf`)
* <kbd>Alt</kbd> + <kbd>C</kbd> — Fuzzy find directory and immediately `cd` into it (`fzf`)

---

## 🔍 Search & File Inspection

* **`fif [query]`** — **Interactive Find In Files**: Live ripgrep + `bat` preview; <kbd>Enter</kbd> edits at line
* **`rg <pattern>`** — Ultra-fast recursive regex search across project (`ripgrep`, honors `.gitignore`)
* **`rga <pattern>`** — Search text inside PDFs, Word docs (`.docx`), `.zip`, `.tar.gz`, and SQLite (`ripgrep-all`)
* **`bat <file>`** — Enhanced `cat` with syntax highlighting, line numbers, and Git change markers
* **`glow <file>`** — Render Markdown in terminal with GitHub styling

---

## ⚡ Shell & Productivity

* `<space><cmd>` — Run command without saving to shell history (`HIST_IGNORE_SPACE`)
* <kbd>Tab</kbd> — Fuzzy completion popup with live previews (`fzf-tab`, `eza` for dirs, `bat` for files)
* <kbd>Ctrl</kbd> + <kbd>R</kbd> — Interactive command history search with fuzzy filtering (`fzf`)
* <kbd>→</kbd> or <kbd>End</kbd> — Accept `zsh-autosuggestions` ghost text completion
* **`./setup.sh [minimal|required|full]`** — Run setup with target mode (pass `--verify` for `doctor.sh` health check)
* **`~/.zshrc.local`** — Machine-specific private overrides and secrets (chmod `600`, untracked by Git)

---

## ☸️ Containers, Cloud & Kubernetes

* **`k`** — `kubectl` CLI shortcut (`k get pods`)
* **`kx`** / **`kn`** — Interactive Kubernetes context (`kubectx`) and namespace (`kubens`) switchers
* **`k9s`** — Fullscreen curses UI for Kubernetes cluster management
* **`d`** / **`dc`** — `docker` and `docker compose` shortcuts (auto-falls back to `podman`)
* *FYI (also available)* — `colima`, `podman`, `talosctl`, `kubeconform`, `yamllint`, `jq`, `yq`

---

## 🔐 Secrets & Environment

* **`p <path>`** — Password manager lookup via `pass` (e.g. `p github/token`)
* **`v`** / **`b`** — HashiCorp Vault / OpenBao CLI shortcuts (bidirectional)
* **`use_pass VAR path`** — Injects secret from `pass` into `$VAR` in `.envrc` (scoped to project)
* **`use_vault VAR path [field]`** — Injects secret from Vault/OpenBao into `$VAR` in `.envrc` (`field` defaults to `value`)

---

## 🌐 Remote & SSH (`sshx`)

* **`sshx [alias]`** *(or `fssh`)* — **TUI SSH Manager**: Connect (<kbd>Enter</kbd>), search (<kbd>/</kbd>), add (<kbd>a</kbd>), edit (<kbd>e</kbd>), copy key (<kbd>c</kbd>), delete (<kbd>d</kbd>)
* **`sshx add [target] [alias]`** — Guided wizard to configure new host, keys, and auth in `~/.ssh/config`

---

## 🔏 Git Accounts & Commit Signing (`doppel`)

* **`dop`** *(or `doppel`)* — **TUI Account Browser**: View accounts. Edit (<kbd>e</kbd>), add (<kbd>a</kbd>), bind (<kbd>b</kbd>), default (<kbd>*</kbd>), test (<kbd>t</kbd>), export (<kbd>x</kbd>), upload (<kbd>u</kbd>), delete (<kbd>d</kbd>)
* **`dop whoami [path]`** — Check which account and signing key apply here, with live host connection check
* **`dop add`** — Guided wizard to configure new identity, host, SSH auth key, and commit signing
* **`dop --help`** — View all CLI subcommands (`bind`, `test`, `upload`, `doctor [--fix]`, `uninstall`)
