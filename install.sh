#!/usr/bin/env bash
#
# Stage 1 bootstrap for a fresh NixOS install.
#
#   curl -fsSL https://raw.githubusercontent.com/JulianElda/dotfiles/master/install.sh | bash -s -- <hostname>
#
# Fetches this repo into a temp dir, generates hosts/<hostname>/ from the
# machine it is running on, and switches the system onto the flake. Uses only
# tools present on a vanilla NixOS install (curl, tar, gzip, sudo,
# nixos-rebuild) - no git, no chezmoi, no channels beyond what ships.
#
# Stage 2 (chezmoi init) runs after the reboot; this script prints it.

set -euo pipefail

REPO_USER=JulianElda
REPO_NAME=dotfiles
REPO_BRANCH=master
NIX_SUBDIR=dot_config/nixos   # where the flake lives inside the chezmoi source
KEEP_DIR="$HOME/nixos-bootstrap"

die()  { printf '\nerror: %s\n' "$*" >&2; exit 1; }
info() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# --- arguments -------------------------------------------------------------

HOST="${1:-}"
[ -n "$HOST" ] || die "usage: install.sh <hostname>"
case "$HOST" in
  *[!a-z0-9-]*) die "hostname '$HOST' must be lowercase letters, digits and dashes" ;;
esac

# --- preflight -------------------------------------------------------------

info "Preflight"

[ "$(id -u)" -ne 0 ] || die "run as your normal user, not root (sudo is used where needed)"

# common/configuration.nix declares users.users."julian"; a different primary
# user would leave the machine with two accounts and an empty home.
[ "$(id -un)" = julian ] || die "expected to run as user 'julian', got '$(id -un)'"

# common/configuration.nix hardcodes systemd-boot + canTouchEfiVariables.
[ -d /sys/firmware/efi ] || die "this machine booted in legacy BIOS mode, but common/configuration.nix assumes UEFI + systemd-boot; add a boot.loader override to hosts/$HOST/configuration.nix by hand"

[ -r /etc/nixos/hardware-configuration.nix ] || die "/etc/nixos/hardware-configuration.nix not found - is this a fresh NixOS install?"

for bin in curl tar sudo nixos-rebuild nixos-version; do
  command -v "$bin" >/dev/null || die "missing required tool: $bin"
done

# The release this machine was installed from. Must NOT be copied from another
# host: NixOS reads it to decide stateful defaults (database versions, dir
# layouts) that must stay pinned to the install, not to the current channel.
STATE_VERSION="$(nixos-version | cut -d. -f1,2)"
case "$STATE_VERSION" in
  [0-9][0-9].[0-9][0-9]) ;;
  *) die "could not parse a release from 'nixos-version' (got '$(nixos-version)')" ;;
esac

echo "host          : $HOST"
echo "user          : $(id -un)"
echo "firmware      : UEFI"
echo "stateVersion  : $STATE_VERSION"

# --- fetch -----------------------------------------------------------------

info "Fetching $REPO_USER/$REPO_NAME@$REPO_BRANCH"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

curl -fsSL "https://github.com/$REPO_USER/$REPO_NAME/archive/refs/heads/$REPO_BRANCH.tar.gz" \
  | tar -xz -C "$WORK" --strip-components=1

FLAKE="$WORK/$NIX_SUBDIR"
[ -f "$FLAKE/flake.nix" ] || die "no flake.nix under $NIX_SUBDIR in the fetched archive"
[ -d "$FLAKE/common" ]    || die "no common/ under $NIX_SUBDIR in the fetched archive"

# --- generate the host -----------------------------------------------------

info "Generating hosts/$HOST"

[ ! -d "$FLAKE/hosts/$HOST" ] || die "hosts/$HOST already exists in the repo; nothing to bootstrap"

mkdir -p "$FLAKE/hosts/$HOST"

# The installer's own scan, not a fresh one: it reflects the partitioning that
# was actually chosen at install time.
sudo cat /etc/nixos/hardware-configuration.nix > "$FLAKE/hosts/$HOST/hardware.nix"

cat > "$FLAKE/hosts/$HOST/configuration.nix" <<EOF
{ ... }:

{
  imports = [
    ../../common/configuration.nix
    ./hardware.nix
  ];

  networking.hostName = "$HOST";

  # The NixOS release this machine was installed with. Never copy to a new host.
  system.stateVersion = "$STATE_VERSION";
}
EOF

cat > "$FLAKE/hosts/$HOST/home.nix" <<EOF
{ ... }:

{
  imports = [ ../../common/home.nix ];

  home.stateVersion = "$STATE_VERSION";
}
EOF

# Survive the reboot: stage 2 copies these into the chezmoi source, because the
# pushed repo does not know about this host yet.
mkdir -p "$KEEP_DIR/hosts"
rm -rf "${KEEP_DIR:?}/hosts/$HOST"
cp -r "$FLAKE/hosts/$HOST" "$KEEP_DIR/hosts/$HOST"
echo "saved to $KEEP_DIR/hosts/$HOST"

# --- build -----------------------------------------------------------------

info "Building and switching to .#$HOST"
echo "(sudo will prompt on the terminal; this takes a while on first run)"

# Flakes are not enabled yet on a vanilla install - the flake being built turns
# them on permanently, so this override is needed exactly once.
sudo nixos-rebuild switch --flake "$FLAKE#$HOST" \
  --option experimental-features "nix-command flakes"

# --- done ------------------------------------------------------------------

info "Stage 1 complete - reboot, then run stage 2"

cat <<EOF
  sudo reboot

Then, with git and chezmoi now installed by the config:

  chezmoi init https://github.com/$REPO_USER/$REPO_NAME.git
  cp -r $KEEP_DIR/hosts/$HOST \\
        ~/.local/share/chezmoi/$NIX_SUBDIR/hosts/
  chezmoi apply

  # confirm the permanent copy builds the same system
  sudo nixos-rebuild switch --flake ~/.config/nixos#$HOST

  # then publish the new host
  cd ~/.local/share/chezmoi
  git remote set-url origin git@github.com:$REPO_USER/$REPO_NAME.git
  git add -A $NIX_SUBDIR && git commit -m "feat(nixos): add $HOST" && git push

Finally work through ~/installation-checklist.md.
EOF
