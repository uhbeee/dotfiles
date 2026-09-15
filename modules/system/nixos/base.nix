# The library's NixOS base: system-side preferences portable to any NixOS
# machine. Deliberately small - machine facts (hardware, disks, networking,
# user accounts, swap, binfmt) belong in the consuming machines repo's host
# file, never here.
{ lib, ... }:

{
  # Flake-based rebuilds are how every machine consuming this library
  # applies itself; no host should have to re-enable the commands. A list,
  # not mkDefault: consumer additions merge in rather than replace.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # The library's shell is zsh (modules/home/common/zsh.nix). Enabling it
  # system-side puts it in /etc/shells and wires session integration, so a
  # host file can set users.users.<name>.shell = pkgs.zsh. mkDefault: a
  # preference, so a consumer's plain assignment wins.
  programs.zsh.enable = lib.mkDefault true;
}
