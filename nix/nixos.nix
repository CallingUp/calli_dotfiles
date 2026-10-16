{ config, lib, pkgs, ... }:
{
  options.services.hakuDesktop.enable = lib.mkEnableOption "Haku desktop prerequisites (configure the user via Home Manager)";
  config = lib.mkIf config.services.hakuDesktop.enable {
    programs.niri.enable = true;
    services.pipewire = { enable = true; pulse.enable = true; wireplumber.enable = true; };
    security.rtkit.enable = true;
    networking.networkmanager.enable = true;
    hardware.bluetooth.enable = true;
    services.upower.enable = true;
    security.pam.services.hyprlock = {};
    fonts.packages = [ pkgs.dejavu_fonts ];
    environment.systemPackages = [ pkgs.xwayland-satellite ];
    # No display-manager, NVIDIA, disk, power-profile or login-shell changes.
  };
}
