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
      mk = user: home: home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = builtins.currentSystem;
          overlays = [ dotfiles.overlays.default ];
          config.allowUnfree = true;
        };
        modules = [
          dotfiles.homeManagerModules.default
          {
            home.username = user;
            home.homeDirectory = home;
            home.stateVersion = "25.05";
          }
        ];
      };
    in {
      homeConfigurations."synthea" = mk "synthea" "/opt/oddhome1";
      homeConfigurations."quorra" = mk "quorra" "/Users/quorra";
    };
}
EOF

check_user() { # check_user <username> <homedir>
  local u=$1 home=$2 out closure links
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
}

check_user synthea /opt/oddhome1
check_user quorra  /Users/quorra

exit $fail
