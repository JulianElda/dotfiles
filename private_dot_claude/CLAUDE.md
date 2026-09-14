# Claude Code — Home Configuration

## Git

- Commit messages must be a single line (conventional commit title only) — no
  body, apart from the attribution trailers Claude Code appends.

## System Tools

Prefer the Rust tools over their classic counterparts: `rg` over `grep`, `fd` over
`find`, `sd` over `sed`, `xh` over `curl`, `dust` over `du`, `hyperfine` over `time`.

Interactive zsh aliases `ls` to `eza` and `cat` to `bat`; use `\ls`, `\cat` or
`command ls` when exact coreutils output or flags matter.

### Search & Edit

- `rg` (ripgrep) — content search
- `fd` — file finder
- `sd` — find & replace (plain regex syntax, no `sed` escaping)
- `ast-grep` — structural search & rewrite by syntax tree

### Languages & Runtimes

- `bun` / `bunx` — prefer over `node`, `npm`, and `npx`
- `node` / `npm` / `npx`
- `tsc` (typescript)
- `uv` / `uvx` — Python package manager and tool runner; `uvx ruff` (lint/format)
  and `uvx ty` (type check) are fetched on demand, not installed
- `python` / `python3`
- `go`, `golangci-lint`

### Build, Test & Benchmark

- `just` — task runner; check for a `justfile` before guessing commands
- `hyperfine` — command benchmarking (`hyperfine --warmup 3 'cmd a' 'cmd b'`)

### Git & CI

- `git`
- `gh` (GitHub CLI) — read-only; never write/create (PRs, issues, comments, etc.) unless explicitly asked
- `difft` (difftastic) — structural diff; `git difft` for a syntax-aware `git diff`
- `lefthook` — git hooks runner (`lefthook run pre-commit`)
- `actionlint` — GitHub Actions workflow linter
- `editorconfig-checker` — verify files against `.editorconfig`
- `goreleaser` — `goreleaser check` validates `.goreleaser.yaml`

### Data & HTTP

- `jq`
- `yq` / `xq` — YAML / XML
- `mlr` (miller) — CSV/TSV
- `xh` — HTTP client
- `curl`

### Documents

- `pdftotext`
- `ocrmypdf` — add a text layer to scanned PDFs before `pdftotext`

### Files & System

- `dust` — disk usage (not a `du` drop-in: `-s` is apparent size, `-d` is depth)
- `wl-copy` / `wl-paste` — Wayland clipboard. `wl-copy` forks a process that holds
  inherited stdout open, so redirect it (`… | wl-copy >/dev/null 2>&1`) or the
  command hangs.

### Containers & Infrastructure

- `docker`
- `docker compose`

## System Configuration

NixOS, so the system is declarative — packages cannot be installed imperatively.

- The config flake is `~/.config/nixos`, **not** `/etc/nixos`.
- User tools are declared in `home.packages` in
  `~/.config/nixos/common/cli-tools.nix` (CLI) and `common/desktop-apps.nix` (GUI).
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
