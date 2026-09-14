{ ... }:

{
  # Git identity is deliberately NOT committed: see the governing principle in
  # AGENTS.md. It lives in ~/.gitconfig.local, which git includes at runtime and
  # nix never reads, so this repo stays usable by anyone as-is.
  # The machines repo setup doc covers creating that file; without it git asks
  programs.git = {
    enable = true;
    includes = [ { path = "~/.gitconfig.local"; } ];
  };
}
