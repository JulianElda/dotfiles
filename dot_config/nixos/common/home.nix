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
    BUN_INSTALL = "$HOME/.bun";
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
  };
  
  home.sessionPath = [
    "$HOME/.bun/bin"
    "$HOME/.local/bin"
    "$HOME/go/bin"
  ];
}
