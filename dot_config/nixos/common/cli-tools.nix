# Headless CLI tools and runtimes.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # languages & runtimes
    nodejs
    bun
    typescript
    python3
    uv
    go
    golangci-lint

    # language servers (helix); oxlint runs per repo via bunx
    typescript-language-server
    svelte-language-server
    vscode-langservers-extracted # css, html, json, eslint
    tailwindcss-language-server
    gopls
    golangci-lint-langserver
    yaml-language-server
    marksman
    taplo

    # git
    delta
    difftastic
    github-cli # gh
    lefthook

    # ci & release
    actionlint
    editorconfig-checker
    goreleaser

    # build, test & benchmark
    just
    hyperfine

    # shell scripts
    shellcheck
    shfmt

    # search & edit
    ripgrep
    fd
    sd
    ast-grep

    # files & terminal
    bat # cat
    eza # ls
    dust # du
    yazi
    wl-clipboard # wl-copy / wl-paste; lets helix paste from other apps

    # data & http
    jq
    yq # provides xq
    miller
    gron
    xh

    # documents
    poppler-utils # pdftotext
    ocrmypdf

    # dotfiles & secrets
    chezmoi
    age
    gocryptfs

    # ai coding agents
    claude-code
  ];

  # nix-index with the prebuilt database from the nix-index-database flake
  # input, plus comma: `, <cmd>` runs a program without installing it.
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;

  # tldr: tealdeer ships no pages; auto_update fetches the cache on first use
  # and refreshes it when stale, so `tldr <cmd>` never fails on an empty cache.
  programs.tealdeer = {
    enable = true;
    settings.updates.auto_update = true;
  };
}
