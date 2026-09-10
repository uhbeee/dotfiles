{ pkgs, user, ... }:

{
  # Identity stays here, at the entry point, not in any module.
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";

  # home.packages concatenates across modules in import order, so it stays in
  # this root module, after home-manager's own contributions, exactly where the
  # pre-split file put it. The list itself lives in lib/base-packages.nix,
  # which the flake also exports as `lib.basePackages`: one list, one place,
  # whether the library installs it or a consumer filters it.
  home.packages = import ./lib/base-packages.nix pkgs;
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
    ./modules/home/common/core.nix
    ./modules/home/common/zsh.nix
    ./modules/home/common/starship.nix
    ./modules/home/common/git.nix
    ./modules/home/common/gh.nix
    ./modules/home/common/neovim.nix
    ./modules/home/common/agents.nix
    ./modules/home/common/pi.nix
    ./modules/home/darwin/wezterm.nix
    ./modules/home/darwin/herdr.nix
    ./modules/home/darwin/claude.nix
    ./modules/home/darwin/flycut.nix
    ./modules/home/darwin/screenshots.nix
  ];
}
