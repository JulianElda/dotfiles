# Handoff: port 2026-09-14 changes from the work dotfiles repo

**Source:** `~/.local/share/chezmoi` (Arch + WSL2 + Windows Terminal, work machine)
**Target:** `~/thelema/dotfiles` (Linux / NixOS)

One day's worth of changes — 15 commits, all shell/editor/terminal tooling. Below is
the general list with config contents inlined. Nothing here has been verified against
the target machine; treat the contents as a starting point and adapt package names,
binary names and paths to whatever that machine actually has.

Deliberately **not** ported: `pkglist-explicit.txt` (a `pacman -Qqe` dump — meaningless
on NixOS) and the encrypted SSH keys. The tool list at the bottom is the useful part of
the package manifest.

## Working discipline

Same as here: chezmoi applies **copies, not symlinks**. Edit the target under `$HOME`,
then `chezmoi re-add <target>` to pull it back into the source. Editing the source and
`chezmoi apply`-ing works too but deploys sight-unseen. Finish with an empty
`chezmoi status`.

Note that `~/thelema/dotfiles/.chezmoiignore` only exempts the three root files it names,
so any **new** root-level file becomes a real target in `$HOME`. Add it to
`.chezmoiignore` if it is documentation.

---

# 1. zsh startup performance

Two independent wins, ~200ms of a 223ms startup. Both fully portable.

## 1a. Cache compinit

`compinit`'s security audit stats every file in `fpath` on every shell start (44ms).
Run the full check once a day, use the cached dump otherwise.

```zsh
zmodload zsh/complist
autoload -Uz compinit
# compinit's security check (compaudit) stats every file in fpath and cost 44ms
# of a 223ms startup. Run it once a day; use the cached dump the rest of the time.
if [[ -n ~/.zcompdump(N.mh+24) ]]; then compinit; else compinit -C; fi
```

The glob qualifier `(N.mh+24)` = exists, regular file, mtime older than 24 hours.

## 1b. Lazy-load nvm

Sourcing `nvm.sh` cost 152ms (74% of startup) to do little more than put one bin
directory on `PATH`. This resolves nvm's own `default` alias directly, then defines a
stub that loads the real nvm on first call.

```zsh
# nvm: sourcing nvm.sh cost 152ms -- 74% of shell startup -- to do little more
# than put one bin directory on PATH. Resolve nvm's own default alias instead, so
# `nvm alias default <v>` still takes effect here without editing this file.
export NVM_DIR="$HOME/.nvm"
() {
  local want
  [[ -r $NVM_DIR/alias/default ]] && want=v${$(<$NVM_DIR/alias/default)#v}
  local -a bin=($NVM_DIR/versions/node/$want/bin(N/))
  # a symbolic default (lts/*, node) won't resolve above; use the newest install
  (( $#bin )) || bin=($NVM_DIR/versions/node/*/bin(N/on[-1]))
  (( $#bin )) && path=($bin[1] $path)
}

# load the real nvm on first use, so `nvm install`/`nvm use` still work and pay
# the 152ms only when actually called
nvm() {
  unset -f nvm
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
  nvm "$@"
}
```

**Skip this entirely if node is managed by nix there** — nvm is the wrong layer on NixOS.

---

# 2. zoxide

Frecency `cd`. `z <part>` jumps, `zi <part>` picks interactively via fzf.

```zsh
# zoxide: `z <part>` jumps by frecency, `zi <part>` picks interactively via fzf.
# Hooks chpwd rather than precmd, so it costs nothing per prompt. Must stay
# after compinit -- its `compdef` for `z` is guarded and silently skipped
# otherwise, leaving the command working but without tab completion.
eval "$(zoxide init zsh)"
```

Ordering matters: after `compinit`, or you lose tab completion silently.

---

# 3. `$VISUAL` / `$EDITOR`

```zsh
# editor: most tools check $VISUAL before $EDITOR, so set both -- leaving one
# empty means anything that exports it silently wins.
export VISUAL=helix
export EDITOR=helix
```

**Binary name differs per distro.** Arch's `helix` package installs the binary as
`helix`; nixpkgs installs it as `hx`. Check with `command -v hx helix` and set
accordingly. Symptom of getting it wrong: `o` in yazi and `chezmoi edit` fail silently,
falling back to a `vi` that may not exist.

---

# 4. Helix

New config. Both files are portable; the **language-server package names are Arch-specific**
and need nixpkgs equivalents.

## 4a. `dot_config/helix/config.toml`

```toml
theme = "ayu_mirage"

[editor]
color-modes = true
cursorline = true

[editor.cursor-shape]
normal = "block"
insert = "bar"
select = "underline"

[editor.statusline]
right = ["diagnostics", "selections", "register", "file-encoding"]

[editor.lsp]
display-inlay-hints = true

[editor.indent-guides]
render = true

[editor.soft-wrap]
enable = true

# Ctrl-y: browse with yazi and open the pick as a buffer. yazi draws straight to
# /dev/tty, so `insert-output` is really just "block and hand over the terminal" --
# its stdout capture is incidental (and why stray yazi stdout would land in the
# buffer). The printf restores the alt screen and bracketed paste that yazi resets
# on exit; the mouse toggle forces a re-init of mouse reporting. Cancelling yazi
# leaves the chooser file absent, so fall back to the current buffer -- a no-op
# instead of an `:open` with no argument.
[keys.normal]
C-y = [
  ':sh rm -f $HOME/.cache/hx-yazi-chooser',
  ':insert-output yazi "%{buffer_name}" --chooser-file=$HOME/.cache/hx-yazi-chooser',
  ':sh printf "\033[?1049h\033[?2004h" > /dev/tty',
  ':open %sh{cat $HOME/.cache/hx-yazi-chooser 2>/dev/null || echo "%{buffer_name}"}',
  ':redraw',
  ':set mouse false',
  ':set mouse true',
]
```

⚠️ **The Ctrl-y binding is the most terminal-sensitive thing in this handoff.** The
`printf "\033[?1049h\033[?2004h"` line and the mouse false/true toggle are workarounds
for terminal state that yazi resets on exit and does not restore. Whether they are
needed depends on the terminal, not the OS. **Try the binding without those three lines
first**; only add them back for the symptoms they fix (garbled screen after yazi exits,
paste behaving oddly, mouse dead).

## 4b. `dot_config/helix/languages.toml`

```toml
# ---------------------------------------------------------------------------
# Language server definitions
# ---------------------------------------------------------------------------

# ESLint. Repos use flat config (eslint.config.mjs); some are still on
# .eslintrc.json. "auto" working-directory lets each package in a monorepo
# resolve its own config instead of the repo root's.
[language-server.eslint]
command = "vscode-eslint-language-server"
args = ["--stdio"]

[language-server.eslint.config]
validate = "on"
run = "onType"
nodePath = ""
rulesCustomizations = []
problems = { shortenToSingleLine = false }
workingDirectory = { mode = "auto" }
codeAction.disableRuleComment = { enable = true, location = "separateLine" }
codeAction.showDocumentation = { enable = true }

# Tailwind v4 (CSS-based config, no tailwind.config.js).
[language-server.tailwindcss]
command = "tailwindcss-language-server"
args = ["--stdio"]

# YAML: SchemaStore gives inline validation for compose, GitHub Actions and
# OpenAPI/AsyncAPI specs without per-file setup.
[language-server.yaml-language-server.config.yaml]
validate = true
completion = true
hover = true
format = { enable = true }

[language-server.yaml-language-server.config.yaml.schemaStore]
enable = true
url = "https://www.schemastore.org/api/json/catalog.json"

# ---------------------------------------------------------------------------
# Language wiring
#
# NOTE: `language-servers` REPLACES the built-in list, so the defaults that
# should stay active are repeated explicitly here.
# ---------------------------------------------------------------------------

[[language]]
name = "typescript"
language-servers = ["typescript-language-server", "eslint"]

[[language]]
name = "javascript"
language-servers = ["typescript-language-server", "eslint"]

[[language]]
name = "tsx"
language-servers = ["typescript-language-server", "eslint", "tailwindcss"]

[[language]]
name = "jsx"
language-servers = ["typescript-language-server", "eslint", "tailwindcss"]

[[language]]
name = "css"
language-servers = ["vscode-css-language-server", "tailwindcss"]

[[language]]
name = "scss"
language-servers = ["vscode-css-language-server", "tailwindcss"]

[[language]]
name = "html"
language-servers = ["vscode-html-language-server", "tailwindcss"]

# Drop ansible-language-server from the default list; it is not installed.
[[language]]
name = "yaml"
language-servers = ["yaml-language-server"]

# Trim uninstalled alternates so `helix --health` stays readable.
[[language]]
name = "markdown"
language-servers = ["marksman"]

[[language]]
name = "toml"
language-servers = ["taplo"]

[[language]]
name = "python"
language-servers = ["ty", "ruff"]

# gopls and docker-langserver work on Helix's defaults; these blocks only drop
# uninstalled alternates so `helix --health` stays readable.
[[language]]
name = "go"
language-servers = ["gopls"]

[[language]]
name = "docker-compose"
language-servers = ["yaml-language-server"]
```

Two things to check on the target:

1. Every `[[language]]` block here **replaces** Helix's built-in server list for that
   language rather than appending. Several blocks exist purely to drop servers that are
   not installed on this machine. If the target installs a different set, those blocks
   should be edited or dropped, not copied blindly. `helix --health` is the check.
2. `command = "vscode-eslint-language-server"` is Arch's binary name; nixpkgs may ship
   it differently. Same for `vscode-css-language-server` / `vscode-html-language-server`.

---

# 5. yazi

`dot_config/yazi/yazi.toml`:

```toml
[mgr]
show_hidden = true
sort_by = "natural"
sort_dir_first = true
```

⚠️ `[mgr]` is the current key name; older yazi releases used `[manager]`. If the target
has an older yazi, rename the section or it silently does nothing.

---

# 6. git

All portable. Adapt the `includeIf` identity routing to the target's directory layout —
on the personal machine there is presumably no `~/elenchus` or `~/workspace`.

## 6a. Push default

```ini
[push]
  autoSetupRemote = true
```

No more `--set-upstream` on first push.

## 6b. delta pager with working mouse scroll

```ini
[delta]
  navigate = true
  side-by-side = true
  pager = less -FR --mouse --wheel-lines=3
```

Requires `less` 550+ for `--mouse`. Without it, the wheel scrolls the terminal's
scrollback instead of the pager.

## 6c. difftastic as opt-in structural diff

`delta` stays the default pager. difftastic is **deliberately not** wired in as the
default `diff.external` — its output is not a valid patch and breaks `git apply` and
`git add -p`.

```ini
[diff]
  tool = difftastic

[difftool]
  prompt = false

[difftool "difftastic"]
  cmd = difft \"$LOCAL\" \"$REMOTE\"

[pager]
  difftool = true

[alias]
  difft = -c diff.external=difft -c core.pager='less -FR --mouse' diff
```

Usage: `git difft` (structural) vs plain `git diff` (delta). The binary is `difft`, the
package is `difftastic`.

> Footnote: the tool inventory in this repo's `dot_claude/CLAUDE.md` still describes an
> earlier `git dd`/`ds`/`dl`/`dt` alias set that was replaced by the single `git difft`
> alias above. Don't copy that stale description across — it's a bug in the source repo.

---

# 7. Terminal / tmux — read the caveats before porting

This is where the machine-specific work is, though **not for WSL reasons** — it's a
knock-on effect of this machine's `cc.zsh` Claude Code helper.

## 7a. tmux pane title (⚠️ probably skip)

On this machine `cc.zsh` re-execs the shell inside `script(1)`, which owns its own pty.
tmux therefore sees `script` as `#{pane_current_command}` and names every window
"script". The fix routes the title out-of-band via OSC 2, which `script` relays through
untouched, and reads it back as `#{pane_title}`.

`dot_tmux.conf`:

```tmux
# Show what the shell is doing in the pane border and the window name.
# #{pane_current_command} cannot work here: cc.zsh re-execs the shell under
# script(1), which owns its own pty, so tmux only ever sees `script`. cc.zsh
# emits OSC 2 instead, which script relays through as #{pane_title}.
set -g pane-border-status top
set -g pane-border-format " #{pane_title} "
set -g automatic-rename-format "#{pane_title}"
set -g pane-active-border-style bg=default,fg=cyan
set -g pane-border-style fg=gray
```

`dot_config/zsh/cc.zsh` (the emitting half):

```zsh
# pane title: the re-exec above puts the shell inside script(1)'s own pty, so
# tmux sees only `script` as #{pane_current_command} and every window is named
# "script". OSC 2 is relayed through script untouched, so announce the title
# from here and read it back as #{pane_title} (see .tmux.conf).
if [[ -n $TMUX ]]; then
  autoload -Uz add-zsh-hook

  # printf, not print -P: a command containing % must not be prompt-expanded
  _cc_title_exec() { printf '\e]2;%s\a' "${1%% *}" }
  _cc_title_idle() { print -Pn $'\e]2;%1~\a' }

  add-zsh-hook preexec _cc_title_exec
  add-zsh-hook precmd  _cc_title_idle
fi
```

**Decision for the target machine:** does it have `cc.zsh` / any `script(1)` re-exec in
its zshrc? If **no** — and it almost certainly doesn't, that helper is work-specific —
then skip both halves and just use the simple form, which is correct there:

```tmux
set -g pane-border-status top
set -g pane-border-format " #{pane_current_command} "
set -g pane-active-border-style bg=default,fg=cyan
set -g pane-border-style fg=gray
```

The `pane-active-border-style` / `pane-border-style` colours are worth taking either way.

## 7b. Cursor shape reset (⚠️ verify, probably wanted)

TUIs leave `DECSCUSR` wherever they happened to exit — helix leaves a block after `:q`
from normal mode, a bar after leaving from insert — and tmux holds that as per-pane state
long after the process is gone, so new prompts inherit it.

```zsh
# cursor: TUIs leave DECSCUSR wherever they happened to exit -- helix leaves a
# block after :q from normal mode, a bar after leaving from insert -- and tmux
# then holds that shape as per-pane state long after the process is gone, so new
# prompts in that pane inherit it. Assert the shape here instead of trusting
# every TUI to restore it. 5 = blinking bar, 6 = steady bar.
autoload -Uz add-zsh-hook
_cursor_bar() { print -rn -- $'\e[5 q' }
add-zsh-hook precmd _cursor_bar
```

This is a tmux + TUI interaction, not a WSL or Windows Terminal one, so it most likely
applies there too — but it is cosmetic and only worth adding if the symptom actually
shows up. Use `6` instead of `5` for a non-blinking bar.

---

# 8. Packages to install

Arch names; translate to nixpkgs. The manifest file itself (`pkglist-explicit.txt`,
a `pacman -Qqe` dump) is not worth porting.

**Tools:** `bat`, `eza`, `dust`, `zoxide`, `yazi`, `helix`, `just`, `htop`,
`difftastic`, `wl-clipboard`

**Language servers** (only what the target actually needs):
`typescript-language-server`, `eslint-language-server`, `tailwindcss-language-server`,
`yaml-language-server`, `bash-language-server`, `dockerfile-language-server`, `gopls`,
`marksman`, `taplo-cli`, `vscode-css-languageserver`, `vscode-html-languageserver`,
`vscode-json-languageserver`

Python's `ty` and `ruff` are referenced in `languages.toml` and come from `uv`/`ruff`
rather than a language-server package.

---

# Suggested order

1. Packages first — most config below is inert without them.
2. zsh: compinit cache, zoxide, `$VISUAL`/`$EDITOR`. Immediate, low-risk, independent.
3. git: all three blocks. Adapt `includeIf` routing.
4. Helix + yazi configs. Expect language-server binary-name fixes; `helix --health` is
   the check.
5. nvm lazy-load — only if nvm is in use there at all.
6. tmux and cursor shape last, and read §7 first. The pane-title change is the one item
   most likely to be actively wrong on the target.
