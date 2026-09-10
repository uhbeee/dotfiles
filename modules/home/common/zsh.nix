{ ... }:

{
  # By default mac gives us z shell but the vanilla one without any of the good stuff. This adds the good stuff!
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    shellAliases = {
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
