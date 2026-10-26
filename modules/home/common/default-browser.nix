{ config, lib, pkgs, ... }:

{
  # Chrome is the library's browser on every platform. "The browser that
  # opens a link" is not platform-bound, so this is a common module with its
  # contents gated - only the mechanism differs per platform (AGENTS.md's
  # cross-platform rule), never the decision.
  #
  # GUI-adjacent, so profile "full" only: a server or container has nothing
  # to open a link with. Gated with mkIf on the contents, never a conditional
  # import (trap A: imports cannot depend on config).
  config = lib.mkIf (config.dotfiles.profile == "full") (lib.mkMerge [

    # macOS. There is no declarative route, and the usual recipes are dead
    # ends: nix-darwin has no system.defaults option for the handler, the
    # LSHandlers array in
    # ~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist
    # is LaunchServices' own to write (hand-edits are ignored), and on macOS
    # 26 the election moved out of that plist into a SettingsStore.sql beside
    # it. The supported call is LSSetDefaultHandlerForURLScheme, which is
    # what `defaultbrowser` makes, and macOS answers it with a confirmation
    # dialog the human clicks once. So this is an activation step, not a
    # setting, and the first switch on a machine is interactive by design.
    #
    # No marker file guards it, deliberately. `defaultbrowser` reads the live
    # handler itself and prints "already set" without prompting, so a no-op
    # rebuild stays quiet without one; and guarding on real state rather than
    # a record means switching back in System Settings reconverges on the
    # next rebuild, which a marker would suppress - the same reasoning as
    # lazy-pins.nix verifying against reality instead of a success record.
    #
    # Failure reports and continues rather than aborting the rebuild:
    # declining the dialog is an ordinary outcome, and so is a standalone
    # home-manager machine that never got the Homebrew cask and so has no
    # Chrome to elect. Either way the next activation asks again.
    (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      home.activation.defaultBrowser = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe pkgs.defaultbrowser} chrome \
          || echo "default browser: could not elect Chrome; will retry on the next activation" >&2
      '';
    })

    # Linux. The association is a file, so it is declarative here - no
    # activation step, no prompt. home-manager owns ~/.config/mimeapps.list
    # once this is on: a machine with an existing unmanaged one must move it
    # aside before the first switch, or checkLinkTargets aborts.
    (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          "text/html" = "google-chrome.desktop";
          "x-scheme-handler/http" = "google-chrome.desktop";
          "x-scheme-handler/https" = "google-chrome.desktop";
          "x-scheme-handler/about" = "google-chrome.desktop";
          "x-scheme-handler/unknown" = "google-chrome.desktop";
        };
      };

      # The browser itself, so the association above resolves to something.
      # A desktop app is the system's to install where the library owns a
      # system scope - on NixOS that is modules/system/nixos/gnome.nix, which
      # installs it next to WezTerm for exactly this reason. Standalone
      # home-manager on a non-NixOS box has no such scope for the library to
      # reach, so home installs it there and only there; submoduleSupport is
      # what distinguishes the two (set by home-manager's NixOS and
      # nix-darwin modules, false standalone), the same discriminator
      # generic-linux.nix uses. google-chrome is unfree: the allowUnfree
      # decision stays the consumer's, made where pkgs is built.
      home.packages = lib.mkIf (!config.submoduleSupport.enable) [ pkgs.google-chrome ];
    })
  ]);
}
