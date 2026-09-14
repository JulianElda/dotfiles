# Headless CLI tools and runtimes.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # languages & runtimes
    nodejs_26
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
    dash # kleidos test dependency

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
}
