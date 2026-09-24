{ config, pkgs, ... }:

{
  imports = [
    ./cli-tools.nix
    ./desktop-apps.nix
    ./plasma.nix
    ./terminal.nix
  ];

  # home.stateVersion is per host; see hosts/<host>/home.nix.

  fonts.fontconfig.enable = false;

  home.sessionVariables = {
    # Most tools check $VISUAL before $EDITOR, so set both; nixpkgs names helix `hx`.
    VISUAL = "hx";
    EDITOR = "hx";
    BUN_INSTALL = "$HOME/.bun";
  };
  
  home.sessionPath = [
    "$HOME/.bun/bin"
    "$HOME/.local/bin"
    "$HOME/go/bin"
  ];
}
