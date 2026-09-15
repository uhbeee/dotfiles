# Placeholder: replace with the real machine's generated hardware config.
# Either let nixos-anywhere write it at install time
# (--generate-hardware-config nixos-generate-config <this path>) or run
# `nixos-generate-config --show-hardware-config` on the machine, and commit
# the result - hardware facts belong in this repo, never in the library.
# No filesystems here: disko.nix owns the disk layout, and nixos-anywhere
# generates this file with --no-filesystems accordingly. (If the machine
# was installed without disko, its generated config carries the
# filesystems; drop disko.nix and its import in that case.)
{ lib, ... }:

{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
