{ config, lib, ... }:

let
  # The consumer-owned identity options this module reads instead of a
  # bespoke argument: the host file sets system.primaryUser and the matching
  # users.users.<name>.home, and paths below derive from them.
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;
in
{
  # Every scalar is mkDefault so a machine overrides one setting by plain
  # assignment; the dock lists stay at normal priority because nix merges
  # lists rather than conflicting on them.
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = lib.mkDefault "Dark";
      KeyRepeat = lib.mkDefault 2;          # fast key repeat
      InitialKeyRepeat = lib.mkDefault 15;  # short delay before repeat
      _HIHideMenuBar = lib.mkDefault true;  # auto-hide the menu bar
      AppleShowAllExtensions = lib.mkDefault true;
    };
    dock.autohide = lib.mkDefault true;
    # Hot corners. nix-darwin has no option for the modifier key; both fire with
    # no modifier held, which is the default.
    dock.wvous-tr-corner = lib.mkDefault 4;   # top right: show desktop
    dock.wvous-br-corner = lib.mkDefault 14;  # bottom right: quick note
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
          path = "${home}/Downloads";
          arrangement = "date-added";
          displayas = "stack";
          showas = "fan";
        };
      }
    ];
    dock.show-recents = lib.mkDefault false;  # or recent apps append themselves to the Dock
    # Screenshots land in ~/Documents/Screenshots, not on the Desktop.
    # modules/home/darwin/screenshots.nix creates that directory: macOS silently
    # falls back to the Desktop if the configured path does not exist.
    screencapture.location = lib.mkDefault "${home}/Documents/Screenshots";
    finder.FXPreferredViewStyle = lib.mkDefault "Nlsv";  # list view by default
    finder.CreateDesktop = lib.mkDefault false;          # clean desktop
    trackpad.Clicking = lib.mkDefault true;              # tap to click
  };
}
