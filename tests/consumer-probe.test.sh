#!/usr/bin/env bash
# Synthetic-consumer regression check (cross-platform plan, phase 4.7).
#
# Builds home configurations for two fictional users from this library and
# asserts, per output: the supplied username AND home path are bound into
# the activation package; none of the real identity patterns appear in file
# contents, closure path names, or symlink targets; and no link points
# outside the nix store into anyone's checkout. Portable synthetic fixtures
# stay in the repo so this remains testable now that no machine output does;
# the real identity patterns are supplied from outside the repo: the
# PROBE_FORBIDDEN environment variable (newline-separated literals), or,
# when unset, the running user's username and git identity.
#
# Inspection failures are failures: a scan that cannot complete never
# reports clean.
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail=0
ok() { echo "ok - $1"; }
bad() { echo "not ok - $1"; fail=1; }

# grep/ugrep convention: 0 match, 1 no match, >1 inspection error.
# Prints MATCH / CLEAN / ERROR so callers can distinguish all three.
scan() { # scan <pattern> <path...>
  local rc=0
  grep -qRIF -- "$1" "${@:2}" 2>/dev/null || rc=$?
  case $rc in 0) echo MATCH;; 1) echo CLEAN;; *) echo ERROR;; esac
}
# Same, over an in-memory string. A herestring, never a producer pipeline:
# grep -q exits at the first match, and under pipefail the producer's
# SIGPIPE would turn a detected match into a clean verdict.
scan_str() { # scan_str <pattern> <string>
  local rc=0
  grep -qF -- "$1" <<<"$2" || rc=$?
  case $rc in 0) echo MATCH;; 1) echo CLEAN;; *) echo ERROR;; esac
}

forbidden=()
if [ -n "${PROBE_FORBIDDEN:-}" ]; then
  while IFS= read -r p; do [ -n "$p" ] && forbidden+=("$p"); done <<<"$PROBE_FORBIDDEN"
else
  forbidden+=("$(whoami)")
  n="$(git config user.name 2>/dev/null || true)"
  e="$(git config user.email 2>/dev/null || true)"
  [ -n "$n" ] && forbidden+=("$n")
  [ -n "$e" ] && forbidden+=("$e")
fi
# An empty pattern list would vacuously pass; refuse to run that way.
[ "${#forbidden[@]}" -gt 0 ] || { echo "no forbidden patterns resolvable"; exit 1; }

probe="$(mktemp -d)"
trap 'rm -rf "$probe"' EXIT
cat > "$probe/flake.nix" <<EOF
{
  inputs = {
    dotfiles.url = "git+file://$LIB";
    nixpkgs.follows = "dotfiles/nixpkgs";
    home-manager.follows = "dotfiles/home-manager";
  };
  outputs = { self, dotfiles, nixpkgs, home-manager, ... }:
    let
      mk = system: user: home: profile: home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ dotfiles.overlays.default ];
          config.allowUnfree = true;
        };
        modules = [
          dotfiles.homeManagerModules.default
          {
            home.username = user;
            home.homeDirectory = home;
            home.stateVersion = "25.05";
            dotfiles.profile = profile;
          }
        ];
      };
    in {
      homeConfigurations."synthea" = mk builtins.currentSystem "synthea" "/opt/oddhome1" "cli";
      homeConfigurations."quorra" = mk builtins.currentSystem "quorra" "/Users/quorra" "full";
      # Eval-only fixtures with explicit systems, so the platform-selection
      # checks below hold on any runner: building Linux needs a Linux
      # builder (phase 6) and building Darwin needs a Mac, but which Claude
      # settings each platform selects is decided at eval time.
      homeConfigurations."linnea" = mk "aarch64-linux" "linnea" "/home/linnea" "cli";
      homeConfigurations."delia" = mk "aarch64-darwin" "delia" "/Users/delia" "full";
      homeConfigurations."freya" = mk "aarch64-linux" "freya" "/home/freya" "full";
    };
}
EOF

check_user() { # check_user <username> <homedir> <profile>
  local u=$1 home=$2 profile=$3 out closure links
  # Build diagnostics stay visible on stderr so environmental failures
  # (sandbox, network, eval) are diagnosable, not silently swallowed.
  if ! out="$(cd "$probe" && nix build --no-link --print-out-paths --impure \
      ".#homeConfigurations.$u.activationPackage")"; then
    bad "$u: activation package builds"
    return
  fi
  ok "$u: activation package builds"

  case "$(scan "$u" "$out/activate")" in
    MATCH) ok "$u: username bound into activate";;
    CLEAN) bad "$u: username absent from activate";;
    *)     bad "$u: username scan could not complete";;
  esac
  case "$(scan "$home" "$out")" in
    MATCH) ok "$u: home path $home bound into the output";;
    CLEAN) bad "$u: home path $home absent from the output";;
    *)     bad "$u: home path scan could not complete";;
  esac

  if ! closure="$(nix path-info -r "$out")"; then
    bad "$u: closure query failed; leak checks not run"
    return
  fi
  # Every symlink target across the closure: catches links (dangling ones
  # included) that point outside the store, e.g. into a developer's
  # checkout. An enumeration error fails the check rather than passing it.
  local links="" t scanfail=0
  while IFS= read -r sp; do
    t="$(find "$sp" -type l -exec readlink {} +)" || scanfail=1
    links+="$t"$'\n'
  done <<<"$closure"
  if [ "$scanfail" -ne 0 ]; then
    bad "$u: symlink enumeration failed; leak checks not run"
    return
  fi
  local outside
  outside="$(printf '%s' "$links" | grep -v '^/nix/store/' | grep '^/' || true)"

  local leak=""; local escapes
  for p in "${forbidden[@]}"; do
    case "$(scan "$p" "$out")" in
      MATCH) leak="$p (contents)"; break;;
      CLEAN) ;;
      *)     bad "$u: content scan for a forbidden pattern could not complete"; return;;
    esac
    case "$(scan_str "$p" "$closure")" in
      MATCH) leak="$p (closure path)"; break;;
      CLEAN) ;;
      *)     bad "$u: closure path scan for a forbidden pattern could not complete"; return;;
    esac
    case "$(scan_str "$p" "$links")" in
      MATCH) leak="$p (symlink target)"; break;;
      CLEAN) ;;
      *)     bad "$u: link target scan for a forbidden pattern could not complete"; return;;
    esac
  done
  if [ -n "$leak" ]; then
    bad "$u: real identity leaked: $leak"
  else
    ok "$u: no real identity in contents, closure paths, or link targets"
  fi
  # Absolute link targets outside the store that also aren't the user's own
  # home tree are checkout-style escapes, forbidden pattern or not.
  escapes="$(printf '%s\n' "$outside" | grep -v "^$home" || true)"
  if [ -n "$escapes" ]; then
    bad "$u: links escape the store: $(printf '%s' "$escapes" | head -3 | tr '\n' ' ')"
  else
    ok "$u: no link target escapes the store"
  fi

  # Profile contract (phase 5): "cli" contains the shell and tools and
  # nothing graphical; "full" carries the GUI-adjacent config. WezTerm's
  # config is the portable marker for both directions; the launch agent
  # and screenshots checks are cli-side only, since what full generates
  # for them is platform-dependent.
  if [ "$profile" = cli ]; then
    if [ -e "$out/home-files/.config/wezterm" ]; then
      bad "$u: cli profile still ships wezterm config"
    else
      ok "$u: cli profile has no wezterm config in home-files"
    fi
    case "$(scan_str "wezterm" "$(ls "$out/home-path/bin" 2>/dev/null)")" in
      MATCH) bad "$u: cli profile has wezterm in home-path packages";;
      CLEAN) ok "$u: cli profile has no wezterm in home-path packages";;
      *)     bad "$u: home-path package scan could not complete";;
    esac
    local gui
    gui="$(find "$out/home-files" -iname '*flycut*' 2>/dev/null || true)"
    if [ -n "$gui" ]; then
      bad "$u: cli profile still ships the Flycut launch agent"
    else
      ok "$u: cli profile has no Flycut launch agent"
    fi
    case "$(scan "Documents/Screenshots" "$out/activate")" in
      MATCH) bad "$u: cli profile still creates the screenshots directory";;
      CLEAN) ok "$u: cli profile has no screenshots activation";;
      *)     bad "$u: screenshots scan could not complete";;
    esac
  else
    if [ -e "$out/home-files/.config/wezterm" ]; then
      ok "$u: full profile ships wezterm config"
    else
      bad "$u: full profile is missing wezterm config"
    fi
  fi
}

check_user synthea /opt/oddhome1 cli
check_user quorra  /Users/quorra  full

# Claude settings selection (phase 5.3): the herdr hook wiring is darwin's,
# so a Linux consumer of the default module list must select the portable,
# hook-stripped settings with no flag overridden anywhere - while darwin
# keeps the authored file, hook included. The selection point is the seed
# script's default= path; eval alone pins it down, no Linux builder needed.
check_seed() { # check_seed <config> <want-pattern> <label>
  local seed
  if ! seed="$(cd "$probe" && nix eval --raw --impure \
      ".#homeConfigurations.$1.config.home.activation.claudeSettingsSeed.data")"; then
    bad "$1: claude seed script eval failed"
    return
  fi
  case "$(scan_str "$2" "$seed")" in
    MATCH) ok "$1: $3";;
    CLEAN) bad "$1: $3 - seed source is wrong";;
    *)     bad "$1: claude seed scan could not complete";;
  esac
}
check_seed linnea "claude-settings-portable.json" \
  "linux consumer seeds the portable hook-free claude settings"

# Darwin's side, by content, against the explicit aarch64-darwin fixture so
# the expectation holds on any runner (quorra rides currentSystem and would
# rightly select portable settings on a Linux host). Its seed source must
# not be the portable file, and the file it does seed (imported into the
# store at eval time, so readable without a Darwin build) must carry the
# guarded herdr hook.
if seed="$(cd "$probe" && nix eval --raw --impure \
    ".#homeConfigurations.delia.config.home.activation.claudeSettingsSeed.data")"; then
  case "$(scan_str "claude-settings-portable.json" "$seed")" in
    CLEAN) ok "delia: darwin consumer does not seed the portable settings";;
    MATCH) bad "delia: darwin consumer wrongly seeds the portable settings";;
    *)     bad "delia: claude seed scan could not complete";;
  esac
  def="$(printf '%s\n' "$seed" | sed -n "s/^default=//p" | head -1 | tr -d \')"
  if [ -f "$def" ]; then
    case "$(scan "herdr-agent-state.sh" "$def")" in
      MATCH) ok "delia: darwin seed carries the guarded herdr hook";;
      CLEAN) bad "delia: darwin seed lost the herdr hook";;
      *)     bad "delia: darwin seed content scan could not complete";;
    esac
  else
    bad "delia: darwin seed source not readable at $def"
  fi
else
  bad "delia: claude seed script eval failed"
fi

# Linux "full" (eval-only): full means the GUI-adjacent *portable* config -
# WezTerm - and never the macOS-only pieces, whose modules gate on platform
# as well as profile. Checked as one attrset so a wrong value names itself.
if lin_full="$(cd "$probe" && nix eval --json --impure \
    ".#homeConfigurations.freya.config" --apply 'c: {
      flycut = c.launchd.agents ? flycut;
      screenshots = c.home.activation ? screenshotsDir;
      wezterm = c.home.file ? ".config/wezterm";
    }')"; then
  want='{"flycut":false,"screenshots":false,"wezterm":true}'
  if [ "$lin_full" = "$want" ]; then
    ok "freya: linux full keeps wezterm and no darwin-only config"
  else
    bad "freya: linux full mismatch: got $lin_full, want $want"
  fi
else
  bad "freya: linux full eval failed"
fi

# Agent CLI sourcing (phase 8's absorbed 7.2 work): the cc/co aliases need
# `claude` and `codex` on PATH. Linux consumers get both from nixpkgs
# (agent-clis.nix); darwin consumers must NOT - the Homebrew casks own
# them there. Eval-only, so it holds on any runner.
check_agent_clis() { # check_agent_clis <config> <want-json> <label>
  local got
  if ! got="$(cd "$probe" && nix eval --json --impure \
      ".#homeConfigurations.$1.config.home.packages" --apply 'ps:
        let names = map (p: p.pname or p.name or "") ps; in {
          cc = builtins.elem "claude-code" names;
          co = builtins.elem "codex" names;
        }')"; then
    bad "$1: agent CLI package eval failed"
    return
  fi
  if [ "$got" = "$2" ]; then ok "$1: $3"; else bad "$1: $3 - got $got"; fi
}
check_agent_clis freya '{"cc":true,"co":true}' \
  "linux consumer sources claude-code and codex from nixpkgs"
check_agent_clis delia '{"cc":false,"co":false}' \
  "darwin consumer leaves claude/codex to the casks"

# The NixOS composition (phase 8): scaffold the shipped template for real
# and evaluate its NixOS variant against the git-sourced library - the
# same eval a consumer's `nixos-rebuild` would start from. Building needs
# a Linux builder (item 7); evaluation pins down the module wiring now.
tpl="$(mktemp -d)"
trap 'rm -rf "$probe" "$tpl"' EXIT
if (cd "$tpl" && nix flake init -t "$LIB#machine" >/dev/null 2>&1) \
    && sed "s|github:CHANGE-ME/dotfiles|git+file://$LIB|" "$tpl/flake.nix" > "$tpl/flake.nix.new" \
    && mv "$tpl/flake.nix.new" "$tpl/flake.nix"; then
  ok "template scaffolds via nix flake init"
else
  bad "template scaffold failed"
fi
if nixos="$(cd "$tpl" && nix eval --json \
    ".#nixosConfigurations.example-nixos.config" --apply 'c: {
      toplevel = builtins.isString c.system.build.toplevel.drvPath;
      # nixos-anywhere needs the disko install attributes, not just the
      # system: a template without them documents an install it cannot do.
      disko = builtins.isString c.system.build.diskoScript.drvPath;
      gdm = c.services.displayManager.gdm.enable;
      gnome = c.services.desktopManager.gnome.enable;
      wezterm = builtins.any (p: (p.pname or "") == "wezterm")
        c.environment.systemPackages;
      zsh = c.programs.zsh.enable;
      flakes = builtins.elem "flakes" c.nix.settings.experimental-features;
      # The README fresh-install path reconnects over ssh post-install;
      # the shipped host must actually serve it.
      sshd = c.services.openssh.enable;
    }')"; then
  want='{"disko":true,"flakes":true,"gdm":true,"gnome":true,"sshd":true,"toplevel":true,"wezterm":true,"zsh":true}'
  if [ "$nixos" = "$want" ]; then
    ok "template nixos variant evaluates: disko install attrs, gnome desktop, sshd, wezterm, zsh, flakes"
  else
    bad "template nixos variant mismatch: got $nixos, want $want"
  fi
else
  bad "template nixos variant eval failed"
fi

exit $fail
