# One NixOS machine, one directory. Same rule as example.nix: identity and
# machine facts live here, never in the library. This example describes a
# UEFI desktop; for a server, drop the desktop import in flake.nix and say
# "cli" below.
{ dotfiles, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ./disko.nix ];

  networking.hostName = "alices-nixos";      # names the flake output too
  networking.networkmanager.enable = true;

  boot.loader.systemd-boot.enable = true;    # UEFI; use grub on BIOS machines
  boot.loader.efi.canTouchEfiVariables = true;

  # The README's fresh-install path reconnects over ssh after the install,
  # which needs the installed system serving it (NixOS defaults it off).
  # Console-only machine? Drop this and skip that reconnect step.
  services.openssh.enable = true;

  users.users.alice = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
    # For the first console/GDM login; change it with `passwd` immediately.
    # Until then it also answers ssh password prompts, so treat the gap
    # between install and that change as trusted-network-only.
    initialPassword = "change-me";
    # Your call, your key: paste it for key-based ssh instead of passwords.
    # openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA... you@your-machine" ];
  };

  # NixOS's own baseline: the release first installed on this machine.
  # Set once at install, never bumped. Never copy another machine's value.
  system.stateVersion = "26.05";

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.alice = {
    imports = [ dotfiles.homeManagerModules.default ];
    home.stateVersion = "26.05";   # home-manager's baseline; same rule
    dotfiles.profile = "full";     # a desktop; servers say "cli"
  };
}
