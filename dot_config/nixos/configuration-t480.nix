{ ... }:

{
  imports = [ ./configuration.nix ];

  networking.hostName = "nixos_t480";

  # Battery charge thresholds: start charging below 40 %, stop at 80 %.
  # thinkpad_acpi exposes these for both the internal (BAT0) and bay (BAT1)
  # battery; the rule reapplies them when a battery is hot-swapped.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="power_supply", KERNEL=="BAT[01]", ATTR{charge_control_start_threshold}="40", ATTR{charge_control_end_threshold}="80"
  '';
}
