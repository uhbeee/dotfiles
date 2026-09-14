{ config, ... }:

{
  # The screenshot UI caches screencapture.location when it starts, so changing
  # that setting has no visible effect until the process restarts. postActivation
  # runs after the defaults are written. killall exits non-zero when nothing
  # matches, which would abort activation, hence the `|| true`.
  system.activationScripts.postActivation.text = ''
    killall -qu ${config.system.primaryUser} screencaptureui || true
  '';
}
