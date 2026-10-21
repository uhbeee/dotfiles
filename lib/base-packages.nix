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
  # Language toolchains. Build tools are deliberately not here: ./gradlew and
  # a project flake pin their own version next to the code that needs it, and
  # a second one on PATH only shadows it. A JDK is all either needs.
  # To drop it on a machine, excludePackages takes the pname, which differs by
  # platform: "zulu-ca-jdk" on darwin, "openjdk" on linux.
  jdk21     # Java 21 LTS
  # The font everything renders in
  nerd-fonts.hack
]
