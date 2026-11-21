# telemachos on this machine, reachable at https://telemachos.julianelda.io behind Cloudflare Access.
{ pkgs, ... }:

{
  # Start the user service at boot, without a login.
  users.users.julian.linger = true;

  systemd.user.services.telemachos = {
    description = "telemachos";
    wantedBy = [ "default.target" ];
    # Chats run claude, and claude's tools and hooks, from your own profile.
    path = [
      "/run/wrappers"
      "/etc/profiles/per-user/julian"
      "/run/current-system/sw"
    ];
    environment = {
      TELEMACHOS_PORT = "4200";
      TELEMACHOS_REPO_ROOTS = "~/workspace";
      TELEMACHOS_ACCESS_TEAM = "https://calm-bonus-2b28.cloudflareaccess.com";
      TELEMACHOS_ACCESS_AUD = "6b478afaa0268205c324283837b44359843394d7b83d7d5aaa41f7f4dab46f0e";
      TELEMACHOS_OWNER_EMAIL = "julius.polar@gmail.com";
      TELEMACHOS_PUBLIC_ORIGIN = "https://telemachos.julianelda.io";
    };
    serviceConfig = {
      WorkingDirectory = "%h/workspace/telemachos";
      ExecStart = "${pkgs.bun}/bin/bun server.ts";
      Restart = "on-failure";
      RestartSec = 5;
      # SIGTERM to the server alone, so it can end each chat's claude cleanly first.
      KillMode = "mixed";
    };
  };

  services.cloudflared = {
    enable = true;
    tunnels."2d90d8e7-cada-42ee-bec5-5de2f1f8353f" = {
      # A string, not a path literal: a path literal would copy the secret into the Nix store.
      credentialsFile = "/var/lib/cloudflared/2d90d8e7-cada-42ee-bec5-5de2f1f8353f.json";
      ingress."telemachos.julianelda.io" = "http://127.0.0.1:4200";
      default = "http_status:404";
    };
  };

  # Keep serving with the lid closed. Plasma decides while logged in; logind decides before login.
  services.logind.settings.Login.HandleLidSwitch = "ignore";
}
