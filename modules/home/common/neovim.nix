{ config, ... }:

{
  # The whole authored config: store-managed for consumers, checkout link
  # under dotfiles.devCheckout. Plugin pins are handled below; see
  # lazy-pins.nix for the restore-and-verify machinery.
  home.file.".config/nvim".source = config.lib.dotfiles.authored "home/.config/nvim";
}
