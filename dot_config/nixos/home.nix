{ config, pkgs, ... }:

{
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    chezmoi
    ghostty
    zsh-completions

    firefox
    firefox-devedition
    chromium
    brave

    noto-fonts
    iosevka
    ibm-plex

    claude-code
    github-cli
    vscodium

    python3
    uv
    go
    typescript-go
    ocrmypdf
    ast-grep
    sd
    jq
    yq
    age
    gocryptfs
    delta
    lefthook
    ripgrep
    fd
    miller
    poppler-utils
    xh
    actionlint
    editorconfig-checker
    goreleaser
    bun
    nodejs_26

    audacious
    vlc

    cryptomator
    keepassxc

    kdePackages.ark
    kdePackages.kate
    kdePackages.kcalc
    kdePackages.okular
    kdePackages.partitionmanager
    kdePackages.skanpage
    kdePackages.spectacle
    kdePackages.plasma-vault
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

  home.sessionVariables = {
    BUN_INSTALL = "$HOME/.bun";
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
  };
  
  home.sessionPath = [
    "$HOME/.bun/bin"
    "$HOME/.local/bin"
    "$HOME/go/bin"
  ];

  programs.plasma = {
    enable = true;
    # overrideConfig = true;

    workspace = {
      colorScheme = "BreezeDark";
      # theme = "breeze-dark";
      # iconTheme = "breeze-dark";
      wallpaper = "/home/julian/Pictures/wallpaper.jpg";
      cursor.size = 48;
    };

    kscreenlocker = {
      autoLock = false;
      timeout = 0;
    };

    kwin.virtualDesktops = {
      number = 1;
      rows = 1;
    };

    panels = [
      {
        location = "left";

        widgets = [
          {
            kickoff = {
              icon = "/home/julian/Dropbox/Pics/elenor_idle.png";
              sortAlphabetically = false;
              sidebarPosition = "left";
              favoritesDisplayMode = "grid";
              applicationsDisplayMode = "list";
              showButtonsFor = "power";
              showActionButtonCaptions = true;
            };
          }

          {
            iconTasks = {
              launchers = [ ];
            };
          }

          "org.kde.plasma.marginsseparator"
          "org.kde.plasma.systemtray"
          {
            digitalClock = {
              date.enable = false;
              time = {
                showSeconds = "never";
                format = "24h";
              };
              calendar.showWeekNumbers = true;
            };
          }
        ];
      }
    ];

    shortcuts = {
      "KDE Keyboard Layout Switcher"."Switch to Last-Used Keyboard Layout" = "Meta+Alt+L";
      "KDE Keyboard Layout Switcher"."Switch to Next Keyboard Layout" = "Meta+Alt+K";

      kaccess."Toggle Screen Reader On and Off" = "Meta+Alt+S";

      kmix.decrease_microphone_volume = "Microphone Volume Down";
      kmix.decrease_volume = "Volume Down";
      kmix.decrease_volume_small = "Shift+Volume Down";
      kmix.increase_microphone_volume = "Microphone Volume Up";
      kmix.increase_volume = "Volume Up";
      kmix.increase_volume_small = "Shift+Volume Up";
      kmix.mic_mute = [ "Microphone Mute" "Meta+Volume Mute" ];
      kmix.mute = "Volume Mute";

      ksmserver."Lock Session" = [ "Screensaver" "Meta+L" ];
      ksmserver."Log Out" = "Ctrl+Alt+Del";

      kwin."Activate Window Demanding Attention" = "Meta+Ctrl+A";
      kwin."Edit Tiles" = "Meta+T";
      kwin.Expose = [ "Ctrl+F9" "Meta+F9" ];
      kwin.ExposeAll = [ "Launch (C)" "Ctrl+F10" "Meta+F10" ];
      kwin.ExposeClass = [ "Ctrl+F7" "Meta+F7" ];
      kwin."Grid View" = "Meta+G";
      kwin."Kill Window" = "Meta+Ctrl+Esc";
      kwin.MoveMouseToCenter = "Meta+F6";
      kwin.MoveMouseToFocus = "Meta+F5";
      kwin.Overview = "Meta+W";
      kwin."Show Desktop" = "Meta+D";
      kwin."Switch One Desktop Down" = "Meta+Ctrl+Down";
      kwin."Switch One Desktop Up" = "Meta+Ctrl+Up";
      kwin."Switch One Desktop to the Left" = "Meta+Ctrl+Left";
      kwin."Switch One Desktop to the Right" = "Meta+Ctrl+Right";
      kwin."Switch Window Down" = "Meta+Alt+Down";
      kwin."Switch Window Left" = "Meta+Alt+Left";
      kwin."Switch Window Right" = "Meta+Alt+Right";
      kwin."Switch Window Up" = "Meta+Alt+Up";
      kwin."Switch to Desktop 1" = [ "Ctrl+F1" "Meta+F1" ];
      kwin."Switch to Desktop 2" = [ "Ctrl+F2" "Meta+F2" ];
      kwin."Switch to Desktop 3" = [ "Ctrl+F3" "Meta+F3" ];
      kwin."Switch to Desktop 4" = [ "Ctrl+F4" "Meta+F4" ];
      kwin."Walk Through Windows" = [ "Alt+Tab" "Meta+Tab" ];
      kwin."Walk Through Windows (Reverse)" = [ "Alt+Shift+Tab" "Meta+Shift+Tab" ];
      kwin."Walk Through Windows of Current Application" = [ "Alt+`" "Meta+`" ];
      kwin."Walk Through Windows of Current Application (Reverse)" = [ "Alt+~" "Meta+~" ];
      kwin."Window Close" = "Alt+F4";
      kwin."Window Maximize" = "Meta+PgUp";
      kwin."Window Minimize" = "Meta+PgDown";
      kwin."Window One Desktop Down" = "Meta+Ctrl+Shift+Down";
      kwin."Window One Desktop Up" = "Meta+Ctrl+Shift+Up";
      kwin."Window One Desktop to the Left" = "Meta+Ctrl+Shift+Left";
      kwin."Window One Desktop to the Right" = "Meta+Ctrl+Shift+Right";
      kwin."Window Operations Menu" = "Alt+F3";
      kwin."Window Quick Tile Bottom" = "Meta+Down";
      kwin."Window Quick Tile Left" = "Meta+Left";
      kwin."Window Quick Tile Right" = "Meta+Right";
      kwin."Window Quick Tile Top" = "Meta+Up";
      kwin."Window Restore" = "Meta+Backspace";
      kwin."Window to Next Screen" = "Meta+Shift+Right";
      kwin."Window to Previous Screen" = "Meta+Shift+Left";
      kwin.disableInputCapture = "Meta+Shift+Esc";
      kwin.view_actual_size = "Meta+0";
      kwin.view_zoom_in = [ "Meta++" "Meta+=" ];
      kwin.view_zoom_out = "Meta+-";

      mediacontrol.nextmedia = "Media Next";
      mediacontrol.pausemedia = "Media Pause";
      mediacontrol.playpausemedia = "Media Play";
      mediacontrol.previousmedia = "Media Previous";
      mediacontrol.seekbackwardmedia = "Media Rewind";
      mediacontrol.seekforwardmedia = "Media Fast Forward";
      mediacontrol.stopmedia = "Media Stop";

      org_kde_powerdevil.PowerDown = "Power Down";
      org_kde_powerdevil.PowerOff = "Power Off";

      plasmashell."activate application launcher" = [ "Meta" "Alt+F1" ];
      plasmashell."activate task manager entry 1" = "Meta+1";
      plasmashell."activate task manager entry 2" = "Meta+2";
      plasmashell."activate task manager entry 3" = "Meta+3";
      plasmashell."activate task manager entry 4" = "Meta+4";
      plasmashell."activate task manager entry 5" = "Meta+5";
      plasmashell."activate task manager entry 6" = "Meta+6";
      plasmashell."activate task manager entry 7" = "Meta+7";
      plasmashell."activate task manager entry 8" = "Meta+8";
      plasmashell."activate task manager entry 9" = "Meta+9";
      plasmashell.clipboard_action = "Meta+Ctrl+X";
      plasmashell.cycle-panels = "Meta+Alt+P";
      plasmashell."manage activities" = "Meta+Q";
      plasmashell."next activity" = "Meta+A";
      plasmashell."previous activity" = "Meta+Shift+A";
      plasmashell."show dashboard" = "Ctrl+F12";
      plasmashell.show-on-mouse-pos = "Meta+V";
    };

    configFile = {
      kdeglobals.General.TerminalApplication = "ghostty --gtk-single-instance=true";
      kdeglobals.General.TerminalService = "com.mitchellh.ghostty.desktop";
      kdeglobals.General.UseSystemBell = true;
      kdeglobals.KDE.AnimationDurationFactor = 0;
      kdeglobals.KDE.contrast = 4;
      kdeglobals.KDE.frameContrast = 0.2;
      kdeglobals.PreviewSettings.EnableRemoteFolderThumbnail = false;
      kdeglobals.PreviewSettings.MaximumRemoteSize = 0;

      dolphinrc.General.RememberOpenedTabs = false;
      dolphinrc.General.ShowCloseButtonOnTabs = false;
      dolphinrc."KFileDialog Settings"."Places Icons Auto-resize" = false;
      dolphinrc."KFileDialog Settings"."Places Icons Static Size" = 22;

      kiorc.Confirmations.ConfirmDelete = false;
      kiorc.Confirmations.ConfirmEmptyTrash = true;
      kiorc.Confirmations.ConfirmTrash = false;
      kiorc."Executable scripts".behaviourOnLaunch = "alwaysAsk";

      klipperrc.General.IgnoreImages = false;
      klipperrc.General.KeepClipboardContents = false;

      kwalletrc.Wallet."First Use" = false;

      kwinrc.Effect-overview.BorderActivate = 9;
      kwinrc.NightColor.Active = true;
      kwinrc.Plugins.padding = 4;
      kwinrc.Plugins.shakecursorEnabled = false;
      kwinrc.Plugins.zoomEnabled = false;
      kwinrc.Xwayland.Scale = 1;

      plasma-localerc.Formats.LANG = "en_US.UTF-8";
      plasma-localerc.Formats.LC_MEASUREMENT = "de_DE.UTF-8";
      plasma-localerc.Formats.LC_NUMERIC = "de_DE.UTF-8";
      plasma-localerc.Formats.LC_TIME = "de_DE.UTF-8";

    };
  };
}
