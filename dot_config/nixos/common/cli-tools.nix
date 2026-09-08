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
    typescript-go

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
