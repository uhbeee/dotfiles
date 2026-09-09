{ user, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };
  system.stateVersion = 6;
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      _HIHideMenuBar = true;  # auto-hide the menu bar
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
    finder.CreateDesktop = false;          # clean desktop
    trackpad.Clicking = true;              # tap to click
  };
  nix-homebrew = {
    enable = true;
    inherit user;
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";  # remove anything not listed here
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];
    brews =  [
      "herdr"
    ];
    casks = [
      "wezterm"
      "claude-code"
      "codex"
      "flycut"
    ];
    # App Store apps. nix-darwin supplies `mas` itself, so it needs no brew entry.
    # Unlike brews and casks these are exempt from the `zap` cleanup above:
    # removing one here will not uninstall it from the machine.
    #
    # Magnet is here only because it has no Homebrew cask. Anything that does
    # belongs in `casks` above, so a fresh Mac needs no App Store sign-in for it.
    masApps = {
      Magnet = 441258766;
    };
  };
}
