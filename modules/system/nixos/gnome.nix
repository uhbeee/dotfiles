# Plain GNOME, separately importable: whether a host gets a desktop is the
# host file's decision - import this module or don't - never the home
# profile's, which has no existence in the NixOS module system. Each
# switch is a mkDefault preference: a consumer keeping GNOME but swapping,
# say, the display manager overrides by plain assignment.
{ lib, pkgs, ... }:

{
  services.xserver.enable = lib.mkDefault true;
  services.displayManager.gdm.enable = lib.mkDefault true;
  services.desktopManager.gnome.enable = lib.mkDefault true;

  # The library's terminal. Its authored config arrives through the home
  # module at profile "full" (modules/home/common/wezterm.nix); the app
  # itself is the system's to install on NixOS, as the cask is on macOS.
  # A list contribution, so consumer package additions merge in.
  environment.systemPackages = [ pkgs.wezterm ];
}
