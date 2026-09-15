{ config, pkgs, ... }:

{
  # No identity here. This file is the library's exported home module tree:
  # the consumer owns home.username, home.homeDirectory and home.stateVersion,
  # and every module below reads config.home.* instead of asking who you are.

  # The base list lives in lib/base-packages.nix, which the flake also
  # exports as `lib.basePackages`: one list, one place, whether the library
  # installs it or a consumer filters it. Tool-scoped runtime dependencies
  # (pi.nix's nodejs) are the one exception: they belong beside the tool
  # that needs them, and removing the tool's module removes them too.
  home.packages = builtins.filter
    (p: !(builtins.elem (p.pname or p.name or "") config.dotfiles.excludePackages))
    (import ./lib/base-packages.nix pkgs);
  fonts.fontconfig.enable = true;

  # initContent is ordered text: pieces concatenate in module-definition order,
  # and this line belongs after the prompt hooks home-manager itself injects.
  # Defining it here in the root module keeps the pre-split position.
  programs.zsh.initContent = ''
    bindkey '^f' autosuggest-accept
  '';

  # One module per concern. An explicit list, no directory scanning: what is
  # enabled is exactly what is written here.
  imports = [
    ./modules/home/common/options.nix
    ./modules/home/common/managed-settings.nix
    ./modules/home/common/core.nix
    ./modules/home/common/zsh.nix
    ./modules/home/common/starship.nix
    ./modules/home/common/git.nix
    ./modules/home/common/gh.nix
    ./modules/home/common/neovim.nix
    ./modules/home/common/lazy-pins.nix
    ./modules/home/common/agents.nix
    ./modules/home/common/plan-skills.nix
    ./modules/home/common/pi.nix
    ./modules/home/common/agent-clis.nix
    ./modules/home/common/claude.nix
    ./modules/home/common/wezterm.nix
    ./modules/home/darwin/herdr.nix
    ./modules/home/darwin/flycut.nix
    ./modules/home/darwin/screenshots.nix
  ];
}
