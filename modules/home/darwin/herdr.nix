{ config, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";
}
