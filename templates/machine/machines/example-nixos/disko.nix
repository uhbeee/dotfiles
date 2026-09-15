# The machine's disk contract, applied by nixos-anywhere at install time
# and the running system's fstab source afterwards. Set `device` to the
# real target disk before installing - the WHOLE disk named here is wiped.
# The layout is a plain UEFI single-disk shape: GPT, a 1G ESP, the rest
# ext4 root, no swap partition (add zramSwap.enable = true in default.nix,
# or a swap partition here, as the machine needs).
#
# A machine installed some other way (or already running) doesn't need
# this file: remove it and its import, and let the machine's generated
# hardware-configuration.nix carry the filesystems instead.
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/CHANGE-ME";   # e.g. /dev/nvme0n1 or /dev/sda
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
