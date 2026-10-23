# Repository Guidelines for configsh

## Git Workflow & Branching Strategy
- **Feature Development**:
  - Never push new features directly to `main`.
  - Always create a dedicated feature branch using the format `feat/<short-description>`.
  - Push the branch to `origin` and open a GitHub Pull Request (PR) for review and merging.
- **Hotfixes & Minor Patches**:
  - Minor bug fixes, urgent patches, or documentation corrections may be committed and pushed directly to `main`.
- **Commit Signatures**:
  - All git commits must be cryptographically signed using the configured ED25519 key (`sergiu@kerrlab.app`).
- **Commit Style**:
  - Use Conventional Commits formatting (e.g., `feat(setup): ...`, `fix(ghostty): ...`, `docs: ...`).

## Setup Modes & Package Tiers
- **`minimal`**: Base shell (`git`, `zsh`, `curl`), Oh My Zsh + essential plugins, editor, security hardening (`chmod 700`/`600`), SSH key audit.
- **`required`**: Default daily driver setup (`minimal` + `starship`, `eza`, `fzf`, `zoxide`, `direnv`, `ripgrep`, `bat`, `jq`, `fnm`, `go`, `pass`, `vault`/`openbao`, pinentry, `sshx`, `doppel`).
- **`full`**: DevOps & cloud workstations (`required` + `docker`/`podman`, `compose`, `colima`, `kubectl`, `helm`, `kubectx`, `k9s`, `yamllint`, `kubeconform`, `yq`, `ghostty` (macOS/Linux desktop; skipped on WSL), `yazi`, `rga`).
- **`optional`**: Non-blocking extras (`talosctl`, `glow`, `fastfetch`) that are never strictly required in any mode so personal vs. professional workstations both pass prerequisite checks cleanly.

## Validation & Quality Gates
- **Health Checks**:
  - Before committing or opening a PR, always execute `scripts/doctor.sh` and `scripts/check-prerequisites.sh` to ensure all diagnostic checks pass cleanly across modes.
- **CI** (`.github/workflows/ci.yml`, required to merge into `main`):
  - `shellcheck -x --severity=warning` over `setup.sh` and `scripts/`; run it locally before pushing.
  - Syntax checks on Ubuntu and macOS: `bash -n` with the stock `/bin/bash` (3.2 on macOS, which runs `setup.sh` before Homebrew's bash exists, so avoid bash 4+ syntax), `zsh -n .zshrc`, and the Starship TOML.
- **Cross-Platform Compatibility**:
  - Ensure scripts and configurations handle macOS (Darwin) and Linux (Arch/Debian/WSL) differences appropriately.
