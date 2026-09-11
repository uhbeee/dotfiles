{ config, ... }:

{
  nix-homebrew = {
    enable = true;
    # The consumer-owned option, not a bespoke argument.
    user = config.system.primaryUser;
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
      # Chrome self-updates via Keystone (the cask is auto_updates), so brew
      # installs it and then leaves the version alone.
      "google-chrome"
      # Editors. Both casks also put CLIs on PATH: `code` and `code-tunnel`
      # from VS Code, `subl` from Sublime Text. Both self-update.
      "visual-studio-code"
      "sublime-text"
    ];
    # No `masApps` here on purpose. See AGENTS.md: mas cannot reach the App Store
    # session from the activation's sudo context, so brew bundle reads every App
    # Store app as missing and aborts the rebuild trying to reinstall it.
    # Magnet is installed by hand from the App Store; it has no Homebrew cask.
  };
}
