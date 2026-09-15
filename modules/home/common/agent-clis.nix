{ lib, pkgs, ... }:

{
  # The cc/co aliases (zsh.nix) assume `claude` and `codex` on PATH. On
  # macOS the Homebrew casks own both (modules/system/darwin/homebrew.nix);
  # on Linux they install from nixpkgs, verified present in the pinned
  # stable channel for x86_64-linux and aarch64-linux. Agent CLIs are
  # cli-profile tools, so no profile gate. claude-code is unfree; the
  # allowUnfree decision stays the consumer's, made where pkgs is built.
  home.packages = lib.mkIf pkgs.stdenv.hostPlatform.isLinux [
    pkgs.claude-code
    pkgs.codex
  ];
}
