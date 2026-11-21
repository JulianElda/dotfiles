# telemachos on this machine, in Docker, reachable at https://<hostname> behind Cloudflare Access.
{ config, lib, pkgs, ... }:

let
  user = "julian";
  uid = 1000; # id -u
  gid = 100; # id -g
  home = config.users.users.${user}.home;
  port = "4200";
  name = "telemachos";
  publicHost = "telemachos-desktop.julianelda.io";
  # The claude version `just probe` passed against. A flake update that moves
  # claude-code fails the rebuild until it is probed again (see docs/setup.md).
  claudeVersion = "2.1.322";

  docker = config.virtualisation.docker.package;
  agentDir = "/run/telemachos-ssh";

  # Bind a host path at the same path inside. --mount, unlike -v, fails when the
  # source is missing instead of creating a root-owned directory in its place.
  bind = path: "--mount=type=bind,src=${path},dst=${path}";
  bindRo = path: "${bind path},readonly";

  # The same tools as your shell: cli-tools.nix's list (not desktop-apps.nix's,
  # which would make the image 25 GB), plus the base tools a NixOS shell gets
  # from /run/current-system/sw.
  tools = pkgs.buildEnv {
    name = "telemachos-tools";
    paths = (import ../../common/cli-tools.nix { inherit pkgs; }).home.packages ++ (with pkgs; [
      bashInteractive
      coreutils
      findutils
      diffutils
      gnugrep
      gnused
      gawk
      gnutar
      gzip
      unzip
      less
      procps
      which
      curl
      git
      openssh # git over ssh, and ssh-keygen for signed commits
      tini
    ]);
    pathsToLink = [ "/bin" ];
  };

  image = pkgs.dockerTools.streamLayeredImage {
    inherit name;
    contents = [
      tools
      pkgs.dockerTools.usrBinEnv # hooks' #!/usr/bin/env python3
      pkgs.dockerTools.binSh
      pkgs.dockerTools.caCertificates
      (pkgs.dockerTools.fakeNss.override {
        # ssh and git look the user up by uid.
        extraPasswdLines = [ "${user}:x:${toString uid}:${toString gid}::${home}:/bin/bash" ];
        extraGroupLines = [ "users:x:${toString gid}:" ];
      })
    ];
    config = {
      Entrypoint = [ "/bin/tini" "--" ]; # reaps the zombies claude's tools leave
      Env = [
        "HOME=${home}"
        "USER=${user}"
        "LOGNAME=${user}"
        "SHELL=/bin/bash"
        "PATH=${home}/.local/bin:/bin"
        "LANG=C.UTF-8"
        "TZ=${config.time.timeZone}"
        "TZDIR=${pkgs.tzdata}/share/zoneinfo"
        "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
        "SSH_AUTH_SOCK=${agentDir}/agent"
      ];
    };
  };
  imageRef = "${image.imageName}:${image.imageTag}";
in
{
  assertions = [{
    assertion = pkgs.claude-code.version == claudeVersion;
    message = ''
      claude-code is ${pkgs.claude-code.version}, but telemachos's image is pinned to ${claudeVersion}.
      Probe the new version, then set claudeVersion in this file:
        cd ~/workspace/telemachos && NIXPKGS_ALLOW_UNFREE=1 nix shell --impure --inputs-from ~/.config/nixos nixpkgs#claude-code -c just probe
    '';
  }];

  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers.${name} = {
    image = imageRef;
    imageStream = image;
    user = "${toString uid}:${toString gid}";
    workdir = "${home}/workspace/telemachos";
    # Claude saves ~/.claude.json by renaming a new file over it, so a bind of
    # that file goes stale at the host's first save, and the container's own
    # saves fail: a rename can't replace a mount point. Each start copies the
    # host's into the tmpfs home instead; changes made in here end at restart.
    cmd = [ "sh" "-c" ''install -m 0600 /run/host/claude.json "$HOME/.claude.json" && exec bun server.ts'' ];
    environment = {
      TELEMACHOS_HOST = "0.0.0.0"; # inside the container only; published on 127.0.0.1 below
      TELEMACHOS_PORT = port;
      TELEMACHOS_REPO_ROOTS = "~/workspace";
      # Items, the logs and comments, shared with every machine through Dropbox.
      TELEMACHOS_CONTENT = "~/Dropbox/telemachos";
      # chats.json stays on this machine: its sessions only resume from this ~/.claude.
      TELEMACHOS_STATE = "~/workspace/telemachos/data";
      # Names this machine's log and comment files in the shared folder; unique per machine.
      # Not the default hostname(): inside the container that is the container id.
      TELEMACHOS_MACHINE = config.networking.hostName;
      TELEMACHOS_ACCESS_TEAM = "https://calm-bonus-2b28.cloudflareaccess.com";
      TELEMACHOS_ACCESS_AUD = "6b478afaa0268205c324283837b44359843394d7b83d7d5aaa41f7f4dab46f0e";
      TELEMACHOS_OWNER_EMAIL = "julius.polar@gmail.com";
      TELEMACHOS_PUBLIC_ORIGIN = "https://${publicHost}";
    };
    # GH_TOKEN=…, since gh keeps its token in the keyring, which the container can't reach.
    environmentFiles = [ "/var/lib/telemachos/gh.env" ];
    ports = [ "127.0.0.1:${port}:${port}" ];
    # Its own network: on the default bridge any other container could reach
    # the server without Cloudflare headers, which counts as local.
    networks = [ name ];
    tmpFs = {
      "/tmp" = [ "mode=1777" ];
      ${home} = [ "uid=${toString uid}" "gid=${toString gid}" "mode=0700" ];
    };
    extraOptions = [
      "--read-only"
      "--cap-drop=ALL"
      "--security-opt=no-new-privileges"
      # Login, settings, transcripts. Same paths as on the host, or --resume finds nothing.
      (bind "${home}/.claude")
      "--mount=type=bind,src=${home}/.claude.json,dst=/run/host/claude.json,readonly"
      # TELEMACHOS_REPO_ROOTS, which holds this repo and its data/ (TELEMACHOS_STATE).
      (bind "${home}/workspace")
      # TELEMACHOS_CONTENT, synced by the host's Dropbox.
      (bind "${home}/Dropbox/telemachos")
      # git and gh.
      (bindRo "${home}/.gitconfig")
      (bindRo "${home}/.config/git")
      (bindRo "${home}/.config/gh")
      (bindRo "${home}/.ssh/known_hosts")
      (bindRo "${home}/.ssh/id_ed25519.pub") # user.signingkey; the private key stays in the agent
      (bindRo "${home}/.ssh/allowed_signers")
      "--mount=type=bind,src=${agentDir},dst=${agentDir}"
      # ontos, which the SessionStart hook runs, and its store.
      (bindRo "${home}/.local/bin/ontos")
      (bindRo "${home}/.config/ontos")
      (bind "${home}/Dropbox/ontos")
    ];
  };

  systemd.services."docker-${name}" = {
    requires = [ "docker-network-${name}.service" ];
    after = [ "docker-network-${name}.service" ];
    # The stock pre-start streams the whole 4 GB image into docker on every
    # start, a minute or more. The tag is a hash of the image, so load it only
    # when that tag is missing, and drop the tags older builds left.
    serviceConfig.ExecStartPre = lib.mkForce [
      (pkgs.writeShellScript "${name}-load" ''
        ${docker}/bin/docker rm -f ${name} || true
        if ! ${docker}/bin/docker image inspect ${imageRef} >/dev/null 2>&1; then
          ${image} | ${docker}/bin/docker load
        fi
        ${docker}/bin/docker image ls ${name} --format '{{.Repository}}:{{.Tag}}' \
          | ${pkgs.gnugrep}/bin/grep -vxF ${imageRef} \
          | ${pkgs.findutils}/bin/xargs -r ${docker}/bin/docker rmi || true
      '')
    ];
  };
  systemd.services."docker-network-${name}" = {
    description = "Docker network for ${name}";
    requires = [ "docker.service" ];
    after = [ "docker.service" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = "${docker}/bin/docker network inspect ${name} >/dev/null 2>&1 || ${docker}/bin/docker network create ${name}";
  };

  # An ssh-agent holding your key, so chats can push and sign commits without
  # the private key ever being mounted.
  systemd.tmpfiles.rules = [ "d ${agentDir} 0700 ${user} users -" ];
  systemd.user.services.telemachos-ssh-agent = {
    description = "ssh-agent for telemachos";
    wantedBy = [ "default.target" ];
    environment.SSH_AUTH_SOCK = "${agentDir}/agent";
    serviceConfig = {
      Type = "forking";
      ExecStartPre = "${pkgs.coreutils}/bin/rm -f ${agentDir}/agent";
      ExecStart = "${pkgs.openssh}/bin/ssh-agent -a ${agentDir}/agent";
      # Fails for a key with a passphrase: then run ssh-add yourself (docs/setup.md).
      ExecStartPost = "-${pkgs.openssh}/bin/ssh-add %h/.ssh/id_ed25519";
      Restart = "on-failure";
    };
  };

  # Start the agent at boot, without a login.
  users.users.${user}.linger = true;

  services.cloudflared = {
    enable = true;
    tunnels."d17e4b95-b248-46f9-8464-cf41b6745aad" = {
      # A string, not a path literal: a path literal would copy the secret into the Nix store.
      credentialsFile = "/var/lib/cloudflared/d17e4b95-b248-46f9-8464-cf41b6745aad.json";
      ingress.${publicHost} = "http://127.0.0.1:${port}";
      default = "http_status:404";
    };
  };
}
