{ user, ... }:

{
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
    # Dock contents, pinned. macOS cannot remove its built-in apps (the system
    # volume is sealed and read-only), so the way to not see the ones I don't
    # use is to declare exactly what belongs here.
    dock.persistent-apps = [
      { app = "/System/Applications/Apps.app"; }
      { app = "/System/Applications/Messages.app"; }
      { app = "/System/Applications/FaceTime.app"; }
      { app = "/System/Applications/Notes.app"; }
      { app = "/Applications/WezTerm.app"; }
      { app = "/Applications/Google Chrome.app"; }
    ];
    dock.persistent-others = [
      {
        folder = {
          path = "/Users/${user}/Downloads";
          arrangement = "date-added";
          displayas = "stack";
          showas = "fan";
        };
      }
    ];
    dock.show-recents = false;  # or recent apps append themselves to the Dock
    # Screenshots land in ~/Documents/Screenshots, not on the Desktop.
    # modules/home/darwin/screenshots.nix creates that directory: macOS silently
    # falls back to the Desktop if the configured path does not exist.
    screencapture.location = "/Users/${user}/Documents/Screenshots";
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
    finder.CreateDesktop = false;          # clean desktop
    trackpad.Clicking = true;              # tap to click
  };
}
