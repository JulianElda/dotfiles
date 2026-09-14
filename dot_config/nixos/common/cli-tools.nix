# Headless CLI tools and runtimes.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # dotfiles
    chezmoi

    # encryption
    age
    gocryptfs

    # kleidos test dependency
    dash

    # git, ci & release
    delta
    lefthook
    actionlint
    editorconfig-checker
    goreleaser

    # typescript
    typescript

    # file manager
    yazi

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

    # pdf & ocr
    ocrmypdf

    # ai coding agents
    claude-code

    # --- declared in ~/.claude/CLAUDE.md ---

    # languages & runtimes
    nodejs_26
    bun
    python3
    uv
    go
    golangci-lint
    just

    # data
    jq
    yq # provides xq
    miller

    # media
    poppler-utils # pdftotext

    # dev utilities
    ast-grep
    sd
    xh
    github-cli # gh
    ripgrep
    fd
  ];
}
