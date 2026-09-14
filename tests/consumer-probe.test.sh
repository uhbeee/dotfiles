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

exit $fail
