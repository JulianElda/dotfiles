{ ... }:

{
  imports = [
    ../../common/configuration.nix
    ./hardware.nix
  ];

  networking.hostName = "desktop";

  programs.steam.enable = true;

  # The NixOS release this machine was installed with. Never copy to a new host.
  system.stateVersion = "26.05";
}
