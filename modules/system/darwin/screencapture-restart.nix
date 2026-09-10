{ user, ... }:

{
  # The screenshot UI caches screencapture.location when it starts, so changing
  # that setting has no visible effect until the process restarts. postActivation
  # runs after the defaults are written. killall exits non-zero when nothing
  # matches, which would abort activation, hence the `|| true`.
  #
  # This module is imported by darwinModules.default only. configuration.nix
  # carries the same line inline for this Mac: postActivation.text is ordered
  # text, and importing this module there would move the line ahead of
  # home-manager's activation hook and change the system derivation (verified).
  # Phase 4, when the Mac consumes the export itself, removes that copy.
  system.activationScripts.postActivation.text = ''
    killall -qu ${user} screencaptureui || true
  '';
}
