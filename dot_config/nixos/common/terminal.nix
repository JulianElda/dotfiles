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
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

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
    '';
  };
}
