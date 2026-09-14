# Shell and prompt.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    zsh-completions
  ];

  programs.starship.enable = true;

  # Binds Ctrl+R (history), Ctrl+T (files) and Alt+C (cd) in zsh.
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    # compinit's security check (compaudit) stats every file in fpath on each
    # start. Run it once a day; use the cached dump the rest of the time.
    # (N.mh+24) = the dump exists, is a regular file, and is over 24 hours old.
    # The glob is an anonymous function's argument because zsh does not expand
    # globs inside [[ ]] -- there it is a literal, always-true string. compinit
    # leaves an unchanged dump's mtime alone, so touch it after the full check.
    completionInit = ''
      autoload -Uz compinit
      () {
        if (( $# )); then compinit && touch ~/.zcompdump; else compinit -C; fi
      } ~/.zcompdump(N.mh+24)
    '';
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # Interactive shells only; scripts still get the real coreutils. `\ls` or
    # `command cat` bypasses an alias when the original flags are needed.
    shellAliases = {
      ls = "eza --group-directories-first";
      # bat already acts like cat when piped; this keeps it pager- and
      # decoration-free in the terminal too, leaving only the highlighting.
      cat = "bat --paging=never --style=plain";
    };

    history = {
      size = 100000;
      save = 100000;
      # Drop older copies of a repeated command, and never offer the same
      # match twice while searching the entries written before that.
      ignoreAllDups = true;
      findNoDups = true;
    };

    initContent = ''
      [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

      # Up/down walk only the history entries matching what is typed so far,
      # so "nix" + Up cycles nix commands instead of everything.
      autoload -U up-line-or-beginning-search down-line-or-beginning-search
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search
      bindkey '^[[A' up-line-or-beginning-search
      bindkey '^[OA' up-line-or-beginning-search
      bindkey '^[[B' down-line-or-beginning-search
      bindkey '^[OB' down-line-or-beginning-search

      # y: run yazi, then cd the shell to the directory it was quit in. A child
      # process cannot change its parent's cwd, so yazi writes it to a file.
      y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        command yazi "$@" --cwd-file="$tmp"
        IFS= read -r -d "" cwd < "$tmp"
        [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
        rm -f -- "$tmp"
      }
    '';
  };
}
