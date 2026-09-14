# Claude Code — Dotfiles Repo

Repo-level notes, alongside the global `~/.claude/CLAUDE.md` (which covers the
chezmoi edit workflow and the NixOS rebuild rules). Like `README.md`, this file
is listed in `.chezmoiignore` and never lands in `$HOME`.

## Nix Tools

- `, <cmd> [args]` (comma) — runs a program from nixpkgs without installing it,
  looking the package up by binary name (`, pgcli --help`). Use it for one-off
  tools instead of asking for a `home.packages` edit and a rebuild; only declare a
  tool in `common/cli-tools.nix` when it is needed repeatedly.
- `nix-locate <path>` (nix-index) — find which package provides a file or binary
  (`nix-locate --top-level --whole-name bin/dig`) before adding it to the config.
- Both read the prebuilt database from the `nix-index-database` flake input,
  refreshed weekly by `nix flake update nix-index-database` — no local indexing.

## Verifying a NixOS Change

`sudo` is unavailable, but building is not privileged. After editing the flake,
build the closure and diff it against the running system before asking the user
to rebuild:

```bash
nix build ~/.config/nixos#nixosConfigurations.<host>.config.system.build.toplevel -o <scratchpad>/result
nix store diff-closures /run/current-system <scratchpad>/result
```

`nixos-rebuild build` has no `-o` flag and drops `./result` in the working
directory, so prefer `nix build` with an explicit output link.
