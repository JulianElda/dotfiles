# Graphical applications and mime handlers.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # browsers
    brave
    chromium
    firefox

    # editors & terminal
    ghostty
    helix
    vscodium
    zed-editor

    # media
    audacious
    vlc

    # files, documents, secrets
    cryptomator
    dropbox
    keepassxc

    # kde apps
    kdePackages.ark
    kdePackages.kate
    kdePackages.kcalc
    kdePackages.calligra
    kdePackages.okular
    kdePackages.partitionmanager
    kdePackages.skanpage
    kdePackages.spectacle
    kdePackages.plasma-vault
  ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/json" = "org.kde.kwrite.desktop";
      "application/x-docbook+xml" = "org.kde.kwrite.desktop";
      "application/x-yaml" = "org.kde.kwrite.desktop";
      "text/markdown" = "org.kde.kwrite.desktop";
      "text/plain" = "org.kde.kwrite.desktop";
      "text/x-cmake" = "org.kde.kwrite.desktop";

      "application/x-extension-htm" = "firefox.desktop";
      "application/x-extension-html" = "firefox.desktop";
      "application/x-extension-shtml" = "firefox.desktop";
      "application/x-extension-xht" = "firefox.desktop";
      "application/x-extension-xhtml" = "firefox.desktop";
      "application/xhtml+xml" = "firefox.desktop";
      "text/html" = "firefox.desktop";
      "x-scheme-handler/chrome" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";

      "audio/aac" = "audacious.desktop";
      "audio/mp4" = "audacious.desktop";
      "audio/mpeg" = "audacious.desktop";
      "audio/mpegurl" = "audacious.desktop";
      "audio/ogg" = "audacious.desktop";
      "audio/vorbis" = "audacious.desktop";
      "audio/x-flac" = "audacious.desktop";
      "audio/x-mp3" = "audacious.desktop";
      "audio/x-mpegurl" = "audacious.desktop";
      "audio/x-ms-wma" = "audacious.desktop";
      "audio/x-musepack" = "audacious.desktop";
      "audio/x-oggflac" = "audacious.desktop";
      "audio/x-scpls" = "audacious.desktop";
      "audio/x-vorbis" = "audacious.desktop";
      "audio/x-vorbis+ogg" = "audacious.desktop";
      "audio/x-wav" = "audacious.desktop";

      "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
    };
  };
}
