# The library's package list as a plain function, exported from the flake as
# `lib.basePackages`. home.nix consumes it too, so there is exactly one list:
# what the library installs and what a consumer filters are the same data.
# Removal, for a consumer, is the dotfiles.excludePackages option:
#   dotfiles.excludePackages = [ "lazygit" ];
# (never lib.mkForce over home.packages: that discards every
# module-contributed package - zsh, starship, pi's nodejs - not just these).
pkgs:

with pkgs; [
  # Useful CLI tools
  ripgrep   # fast search
  fd        # fast find
  fzf       # fuzzy finder
  jq        # json on the command line
  lazygit
  neovim
  pi-coding-agent  # from the unstable overlay in flake.nix
  # The font everything renders in
  nerd-fonts.hack
]
