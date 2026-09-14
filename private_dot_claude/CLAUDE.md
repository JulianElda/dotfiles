# Claude Code — Home Configuration

## Git

- Commit messages must be a single line (conventional commit title only) — no
  body, apart from the attribution trailers Claude Code appends.

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

## Dotfiles (chezmoi)

Dotfiles are managed with `chezmoi`. The source repo is `~/.local/share/chezmoi`.

- **Always edit the live file in `$HOME`, then run `chezmoi add <live-path>`** to
  propagate the change into the source repo.
- **Never edit files under `~/.local/share/chezmoi` directly.** The source repo is
  a destination, not a working copy.
- Never run `chezmoi apply` to publish an edit — it pushes the source *onto*
  `$HOME` and would discard uncommitted live changes.
- File mode is encoded in the source filename (`private_` = `0600`), so never
  rename or hand-create source files; let `chezmoi add` derive the name.
- After editing any managed file, run `chezmoi add` on it before finishing; leaving
  `chezmoi status` dirty means the next `chezmoi apply` silently reverts the work.
- bat's theme (`~/.config/bat/themes/ayu-mirage.tmTheme`) only takes effect once
  compiled into `~/.cache/bat`, which chezmoi does not manage. Run `bat cache --build`
  after adding or changing a theme, on a fresh machine after `chezmoi apply`, and
  when bat warns about an outdated cache after a nixpkgs update.
