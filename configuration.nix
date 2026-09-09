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
    # Hot corners. nix-darwin has no option for the modifier key; both fire with
    # no modifier held, which is the default.
    dock.wvous-tr-corner = 4;   # top right: show desktop
    dock.wvous-br-corner = 14;  # bottom right: quick note
    # Screenshots land in ~/Documents/Screenshots, not on the Desktop.
    # home.nix creates that directory: macOS silently falls back to the Desktop
    # if the configured path does not exist.
    screencapture.location = "/Users/${user}/Documents/Screenshots";
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
    # No `masApps` here on purpose. See AGENTS.md: mas cannot reach the App Store
    # session from the activation's sudo context, so brew bundle reads every App
    # Store app as missing and aborts the rebuild trying to reinstall it.
    # Magnet is installed by hand from the App Store; it has no Homebrew cask.
  };
}
