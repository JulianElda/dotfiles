{ ... }:

{
  imports = [ ./home.nix ];

  programs.plasma = {
    powerdevil = {
      # On AC: never suspend, never blank, never dim. Just lock on lid close.
      AC = {
        autoSuspend.action = "nothing";
        whenLaptopLidClosed = "lockScreen";
        dimDisplay.enable = false;
        turnOffDisplay.idleTimeout = "never";
      };
      # On battery: dim after 2 min, screen off after 5 min, sleep after 10 min.
      battery = {
        autoSuspend.action = "sleep";
        autoSuspend.idleTimeout = 600;
        whenLaptopLidClosed = "lockScreen";
        dimDisplay.idleTimeout = 120;
        turnOffDisplay.idleTimeout = 300;
      };
      lowBattery = {
        autoSuspend.action = "sleep";
        autoSuspend.idleTimeout = 600;
        whenLaptopLidClosed = "lockScreen";
        dimDisplay.idleTimeout = 120;
        turnOffDisplay.idleTimeout = 300;
      };
    };

    # Backlight, suspend and battery keys present on the laptop keyboard.
    shortcuts = {
      org_kde_powerdevil."Decrease Keyboard Brightness" = "Keyboard Brightness Down";
      org_kde_powerdevil."Decrease Screen Brightness" = "Monitor Brightness Down";
      org_kde_powerdevil."Decrease Screen Brightness Small" = "Shift+Monitor Brightness Down";
      org_kde_powerdevil.Hibernate = "Hibernate";
      org_kde_powerdevil."Increase Keyboard Brightness" = "Keyboard Brightness Up";
      org_kde_powerdevil."Increase Screen Brightness" = "Monitor Brightness Up";
      org_kde_powerdevil."Increase Screen Brightness Small" = "Shift+Monitor Brightness Up";
      org_kde_powerdevil.Sleep = "Sleep";
      org_kde_powerdevil."Toggle Keyboard Backlight" = "Keyboard Light On/Off";
      org_kde_powerdevil.powerProfile = [ "Battery" "Meta+B" ];
    };

    # Input devices built into the ThinkPad T480.
    configFile = {
      kcminputrc."Libinput/1739/0/Synaptics TM3276-022".NaturalScroll = true;
      kcminputrc."Libinput/1739/0/Synaptics TM3276-022".ScrollFactor = 0.5;
      kcminputrc."Libinput/2/10/TPPS\\/2 IBM TrackPoint".NaturalScroll = false;
    };
  };
}
