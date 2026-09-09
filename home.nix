{ config, pkgs, lib, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";
  home.packages = with pkgs; [
    # Userful CLI tools
    ripgrep   # fast search
    fd        # fast find
    fzf       # fuzzy finder
    jq        # json on the command line
    lazygit
    neovim
    pi-coding-agent  # from the unstable overlay in flake.nix
    # The font everything renders in
    nerd-fonts.hack
  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables.EDITOR = "nvim"; # This is the default for now. Might change in the future.

  # By default mac gives us z shell but the vanilla one without any of the good stuff. This adds the good stuff!
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    initContent = ''
      bindkey '^f' autosuggest-accept
    '';
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

  # This is the starship tool that helps customize the prompt on the terminal: all the stuff printed out before the cursor on the terminal. This modifies that!
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  # Git identity lives here so a fresh Mac gets it from the first switch,
  # instead of git stopping the first commit to ask for it.
  programs.git = {
    enable = true;
    settings.user = {
      name = "Abhi Dasari";
      email = "abi.dasari@gmail.com";
    };
  };

  # gitCredentialHelper points git at `gh auth git-credential`, so `git push`
  # rides on the gh login rather than whatever osxkeychain happens to hold.
  # `gh auth login` still has to be run once per machine: the token is a
  # secret and never belongs in this repo.
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };

  # Start Flycut at login. Its own "launch at startup" preference registers a
  # login item outside this repo, so drive it from launchd instead and leave
  # that preference off, or the app starts twice.
  launchd.agents.flycut = {
    enable = true;
    config = {
      ProgramArguments = [ "/Applications/Flycut.app/Contents/MacOS/Flycut" ];
      RunAtLoad = true;
      KeepAlive = false;  # a menu bar app I quit on purpose should stay quit
    };
  };

  # configuration.nix points screencapture here. macOS silently falls back to the
  # Desktop when the directory is missing, so create it rather than assume it.
  home.activation.screenshotsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/Documents/Screenshots"
  '';

  # Edit-in-place: the real file stays in my repo, ~/.config just points at it.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";

  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";

  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";

  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  # Link only the files and directories this repo authors, so Pi's auth, sessions,
  # caches and npm package trees stay local and untracked.
  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/themes";
  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions";
  home.file.".pi/agent/models.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/models.json";
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/settings.json";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
}
