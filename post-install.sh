#!/usr/bin/env bash
#
# Stage 3, after `chezmoi apply` and the rebuild onto ~/.config/nixos: the SSH
# identity, GitHub, the bat theme, the ~/workspace checkouts with their
# .envrc files allowed, and the tools built from them.
#
#   bash ~/.local/share/chezmoi/post-install.sh
#
# Needs Dropbox logged in and synced: the ontos store and the pragma content
# folder live there. Idempotent - every step checks before it acts, so on a
# machine that is already set up it only refreshes allowed_signers, the bat
# cache and the binaries in ~/.local/bin.

set -euo pipefail

GH_USER=JulianElda
WORKSPACE="$HOME/workspace"
# Cloned on every machine; the rest of the account is cloned by hand when needed.
REPOS=(arche dotfiles hestia julianelda.io kleidos ontos pragma)

KEY="$HOME/.ssh/id_ed25519" # ~/.gitconfig signs with $KEY.pub
SIGNERS="$HOME/.ssh/allowed_signers"
CHEZMOI_SRC="$HOME/.local/share/chezmoi"
# Uploading keys needs more than the default login scopes.
SCOPES=admin:public_key,admin:ssh_signing_key

die()  { printf '\nerror: %s\n' "$*" >&2; exit 1; }
info() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# --- preflight -------------------------------------------------------------

info "Preflight"

[ "$(id -u)" -ne 0 ] || die "run as your normal user, not root"

for bin in bat direnv fd git gh go ssh-keygen rg; do
  command -v "$bin" >/dev/null || die "missing $bin - has the rebuild onto ~/.config/nixos run?"
done

EMAIL="$(git config --global user.email)" || die "no user.email in ~/.gitconfig - run chezmoi apply first"

[ -d "$HOME/Dropbox/ontos/entries" ] || die "$HOME/Dropbox/ontos not found - log in to Dropbox and let it sync first"

echo "host  : $(hostname)"
echo "email : $EMAIL"

# --- ssh key ---------------------------------------------------------------

info "SSH key"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [ -f "$KEY" ]; then
  echo "$KEY (kept)"
else
  # user@host, not the email: every machine's key goes to the same account, and
  # the comment is what tells them apart in GitHub's key list later.
  ssh-keygen -t ed25519 -C "$(id -un)@$(hostname)" -f "$KEY"
fi

# Type and base64 only - the form GitHub's API returns keys in.
PUB="$(cut -d' ' -f1,2 "$KEY.pub")"

# --- github ----------------------------------------------------------------

info "GitHub login"

if gh auth status -h github.com >/dev/null 2>&1; then
  echo "logged in (kept)"
else
  # The key is uploaded below, for signing as well; gh's own prompt only
  # offers authentication.
  gh auth login -h github.com -p ssh -w --skip-ssh-key -s "$SCOPES"
fi

# GitHub's server keys, fetched over gh's authenticated HTTPS rather than
# trusted on first use, so the first ssh connection has nothing to confirm.
if ssh-keygen -F github.com >/dev/null; then
  echo "github.com in known_hosts (kept)"
else
  gh api meta --jq '.ssh_keys[] | "github.com " + .' >>"$HOME/.ssh/known_hosts"
  echo "github.com added to known_hosts"
fi

info "GitHub keys"

# $1: the public key list on the account; $2: gh ssh-key's --type for it.
refreshed=
upload_key() {
  # Captured first: rg -q exits on the first match, and under pipefail the
  # SIGPIPE that leaves gh would read as "key missing".
  local keys
  keys="$(gh api "users/$GH_USER/$1" --jq '.[].key')"
  if rg -qxF -- "$PUB" <<<"$keys"; then
    echo "$2 key (already on GitHub)"
    return
  fi
  if [ -z "$refreshed" ]; then
    gh auth refresh -h github.com -s "$SCOPES"
    refreshed=1
  fi
  gh ssh-key add "$KEY.pub" --type "$2" --title "$(hostname)"
}

upload_key keys authentication
upload_key ssh_signing_keys signing

# Every signing key on the account, not just this machine's: otherwise commits
# made on the other machines show "No principal matched" in git log here.
# Derived data, so rewritten on every run; a key revoked on GitHub drops out.
{
  printf '%s\n' "$PUB"
  gh api "users/$GH_USER/ssh_signing_keys" --jq '.[].key'
} | sort -u | awk -v email="$EMAIL" '{ print email, $0 }' >"$SIGNERS.tmp"
mv "$SIGNERS.tmp" "$SIGNERS"
echo "$SIGNERS ($(wc -l <"$SIGNERS") keys)"

# ssh -T exits 1 even on success (GitHub offers no shell), so judge it by the
# greeting; piped straight into rg, pipefail would report the 1.
greeting="$(ssh -T git@github.com 2>&1 || true)"
case "$greeting" in
  *"successfully authenticated"*) echo "ssh -T git@github.com ok" ;;
  *) die "ssh -T git@github.com did not authenticate: $greeting" ;;
esac

# --- chezmoi remote --------------------------------------------------------

info "chezmoi source remote"

# chezmoi init clones over https, since no key exists yet on a fresh machine.
url="$(git -C "$CHEZMOI_SRC" remote get-url origin)"
case "$url" in
  https://*)
    git -C "$CHEZMOI_SRC" remote set-url origin "git@github.com:$GH_USER/dotfiles.git"
    echo "origin switched to ssh"
    ;;
  *) echo "origin $url (kept)" ;;
esac

# --- bat theme -------------------------------------------------------------

info "bat theme"

# chezmoi places ~/.config/bat/themes/ayu-mirage.tmTheme, but bat only reads
# themes compiled into ~/.cache/bat, which chezmoi does not manage.
bat cache --build

# --- workspace -------------------------------------------------------------

info "Workspace"

mkdir -p "$WORKSPACE"
for repo in "${REPOS[@]}"; do
  if [ -d "$WORKSPACE/$repo/.git" ]; then
    echo "$repo (kept)"
  else
    git clone "git@github.com:$GH_USER/$repo.git" "$WORKSPACE/$repo"
  fi
done

info "direnv"

# Every .envrc in the checkouts, a package's as well as a repo root's. Allowing
# only trusts the file; nix-direnv builds each dev shell on the first cd into it.
for repo in "${REPOS[@]}"; do
  while IFS= read -r envrc; do
    direnv allow "$envrc"
    echo "${envrc#"$WORKSPACE"/}"
  done < <(fd -H -t f '^\.envrc$' "$WORKSPACE/$repo")
done

# --- tools -----------------------------------------------------------------

# Built from the checkouts into ~/.local/bin, on PATH via home.sessionPath.
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

# CGO_ENABLED=0 for both: they import net, whose cgo DNS resolver wants gcc,
# and there is none on PATH.

info "kleidos"

(cd "$WORKSPACE/kleidos" && CGO_ENABLED=0 go build -o "$BIN_DIR/kleidos" .)
echo "$BIN_DIR/kleidos"

info "apokryphon"

# Only the binary: `apokryphon init` is interactive and needs kleidos's
# identity in place first.
(cd "$WORKSPACE/hestia/packages/apokryphon" &&
  CGO_ENABLED=0 go build -o "$BIN_DIR/apokryphon" ./cmd/apokryphon)
echo "$BIN_DIR/apokryphon"

# Each repo's setup.sh builds the binary into ~/.local/bin and links its skills.
# The Claude Code lines both scripts print are already in the chezmoi-managed
# ~/.claude/settings.json and CLAUDE.md.

info "ontos"

# Not managed by chezmoi (ontos keeps one store per machine), so seed it here:
# setup.sh would otherwise create an empty store at ~/ontos. The [context]
# section is left to ontos's defaults.
ontos_config="$HOME/.config/ontos/config.toml"
if [ ! -f "$ontos_config" ]; then
  mkdir -p "$(dirname "$ontos_config")"
  printf 'store = "~/Dropbox/ontos"\n' >"$ontos_config"
fi
"$WORKSPACE/ontos/scripts/setup.sh"

info "pragma"

# Its config is managed by chezmoi and already points at ~/Dropbox/pragma.
"$WORKSPACE/pragma/scripts/setup.sh"

# --- done ------------------------------------------------------------------

info "Stage 3 complete"

cat <<EOF
Publish this host if stage 2 has not yet:

  cd ~/.local/share/chezmoi
  git add -A dot_config/nixos && git commit -m "feat(nixos): add $(hostname)" && git push
  rm -rf ~/nixos-bootstrap

Then work through installation-checklist.md.
EOF
