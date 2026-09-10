{ ... }:

{
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
}
