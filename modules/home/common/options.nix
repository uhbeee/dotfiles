{ config, lib, ... }:

{
  options.dotfiles.devCheckout = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "/Users/you/dotfiles";
    description = ''
      Absolute path to a local checkout of this library. When set, every
      authored config file (nvim, wezterm, herdr, claude, pi, the agents
      file) links into that checkout and is editable in place - the library
      developer's mode. When null, the default for everyone else, authored
      files come read-only from the nix store and the machine runs exactly
      what the library declares.
    '';
  };

  # The one way modules reference an authored file. `sub` is a repo-relative
  # path like "home/.config/nvim". Store mode imports the file into the store
  # (read-only); dev mode links into the checkout (editable, no rebuild).
  config.lib.dotfiles.authored = sub:
    if config.dotfiles.devCheckout != null
    then config.lib.file.mkOutOfStoreSymlink "${config.dotfiles.devCheckout}/${sub}"
    else ../../.. + "/${sub}";
}
