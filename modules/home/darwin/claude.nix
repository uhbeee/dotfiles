{ config, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";
}
