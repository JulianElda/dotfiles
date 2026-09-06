# Claude Code — Home Configuration

## Git

- Commit messages must be a single line (conventional commit title only) — no body, no footer.
- Never add a `Co-Authored-By` trailer.

## System Tools

### Languages & Runtimes

- `node`
- `npm` / `npx`
- `bun` / `bunx` — prefer over `node`, `npm`, and `npx`
- `python` / `python3`
- `uv` / `uvx` — Python package manager and tool runner; `uvx ruff` (lint/format)
  and `uvx ty` (type check) are fetched on demand, not installed
- `go`

### Containers & Infrastructure

- `docker`
- `docker compose`

### Data & Databases

- `jq`
- `yq`
- `xq`
- `mlr` (miller)

### Media

- `pdftotext`

### Dev Utilities

- `ast-grep`
- `sd`
- `xh`
- `git`
- `gh` (GitHub CLI) — read-only; never write/create (PRs, issues, comments, etc.) unless explicitly asked
- `rg` (ripgrep)
- `fd` (file finder)
- `curl`

## System Configuration

NixOS, so the system is declarative — packages cannot be installed imperatively.

- The config flake is `~/.config/nixos`, **not** `/etc/nixos`.
- User tools are declared in `home.packages` in `~/.config/nixos/home.nix`.
- Rebuild: `sudo nixos-rebuild switch --flake ~/.config/nixos`
- `sudo` is password-gated and there is no TTY, so rebuilds cannot be run
  unattended — make the edit, then ask the user to run the rebuild.
