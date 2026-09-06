# Shell and prompt.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    zsh-completions
  ];

  programs.starship.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    initContent = ''
      [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
    '';
  };
}
