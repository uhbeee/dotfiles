{ lib, ... }:

{
  # By default mac gives us z shell but the vanilla one without any of the good stuff. This adds the good stuff!
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    # Each alias is a default, overridable per machine by plain assignment;
    # priorities apply per attribute, so overriding one keeps the rest.
    shellAliases = lib.mapAttrs (_: lib.mkDefault) {
      ".." = "cd ..";
      la = "ls -al";
      log = "git log --graph --oneline --all --decorate";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";
    };
  };
}
