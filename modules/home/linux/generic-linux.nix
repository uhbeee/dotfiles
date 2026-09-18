{ config, lib, pkgs, ... }:

{
  # Non-NixOS Linux hosts (Ubuntu, servers, Ubuntu-under-WSL) need
  # home-manager's generic-Linux integration: session variables sourced from
  # the login shells, nix's profile.d wiring, XDG data dirs and terminfo
  # reaching into /usr/share - everything an OS built by nix would have done
  # itself. isLinux alone does not describe that boundary: NixOS machines
  # consume this same module tree through home-manager's NixOS module, where
  # the OS owns that wiring and genericLinux must stay off.
  # submoduleSupport.enable marks exactly that embedding (set by
  # home-manager's NixOS and nix-darwin modules, false standalone), and
  # mkDefault leaves the odd case - standalone home-manager on a NixOS
  # machine - one plain assignment away. Safe to assign on darwin: the
  # option always exists; only its effects are Linux-gated.
  targets.genericLinux.enable = lib.mkDefault
    (pkgs.stdenv.hostPlatform.isLinux && !config.submoduleSupport.enable);

  # genericLinux wires PATH by sourcing nix's own nix.sh through the
  # session variables, but nix.sh guards on $USER and $HOME and silently
  # no-ops when either is unset - the reality inside containers and
  # anything else that skips login(1), where the rest of the session
  # wiring still runs and the tools then resolve to nothing. The shell
  # must not depend on that guard: put the profile bins on PATH
  # explicitly, idempotently so nested shells do not stack it. The
  # profile location is the consumer's (nix.useXdg, xdg.stateHome), so
  # it comes from home-manager's resolved home.profileDirectory - the
  # same value genericLinux itself wires the XDG dirs with - never a
  # hardcoded ~/.nix-profile.
  programs.zsh.envExtra = lib.mkIf config.targets.genericLinux.enable ''
    case ":$PATH:" in
      *":${config.home.profileDirectory}/bin:"*) ;;
      *) export PATH="${config.home.profileDirectory}/bin:/nix/var/nix/profiles/default/bin:$PATH" ;;
    esac
  '';
}
