# telemachos on this machine, reachable at https://telemachos-desktop.julianelda.io behind Cloudflare Access.
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
      TELEMACHOS_PUBLIC_ORIGIN = "https://telemachos-desktop.julianelda.io";
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
    tunnels."d17e4b95-b248-46f9-8464-cf41b6745aad" = {
      # A string, not a path literal: a path literal would copy the secret into the Nix store.
      credentialsFile = "/var/lib/cloudflared/d17e4b95-b248-46f9-8464-cf41b6745aad.json";
      ingress."telemachos-desktop.julianelda.io" = "http://127.0.0.1:4200";
      default = "http_status:404";
    };
  };
}
