{ user, ... }:

{
  imports = [
    ./modules/system/darwin/defaults.nix
    ./modules/system/darwin/homebrew.nix
  ];

  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };
  system.stateVersion = 6;

  # The screenshot UI caches screencapture.location when it starts, so changing
  # that setting has no visible effect until the process restarts. postActivation
  # runs after the defaults are written. killall exits non-zero when nothing
  # matches, which would abort activation, hence the `|| true`. Ordered text:
  # it merges with home-manager's activation hook in module-definition order,
  # so it stays in this root module to keep its pre-split position; importing
  # it moves the text ahead of home-manager's and changes the hash (verified).
  # modules/system/darwin/screencapture-restart.nix carries the same line for
  # darwinModules.default consumers; phase 4, when this machine consumes the
  # export itself, removes this copy.
  system.activationScripts.postActivation.text = ''
    killall -qu ${user} screencaptureui || true
  '';
}
