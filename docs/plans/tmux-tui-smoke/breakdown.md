# tmux for the TUI smoke - breakdown

> **Status:** 1/1 items done; last synced 2026-09-13 (5b911d2)

## Item 1: Declare tmux in the exported home configuration

- **Goal:** Add `pkgs.tmux` to the library's exported home
  configuration per plan decisions 1-3, with a rationale comment in
  repo style.
- **Blocking edges:** none.
- **Validation:** `git grep -n "tmux" -- 'lib/*.nix' 'modules/**' home.nix`
  exits 0; `bash tests/consumer-probe.test.sh` exits 0; human: after
  `darwin-rebuild switch` from the machines repo, `tmux -V` exits 0 and
  `bash tests/pi-calm.test.sh` does not print
  `skip: pi or tmux not found` (activation is the consuming machine's
  step; this library repo cannot activate).
- **Exit criteria:** The declaration exists in exactly one place, with
  a rationale comment; the consumer probe is green.
- **Status:** done 5b911d2 (review and conformance clean 2026-09-13;
  deviation from draft: the validation line's PATH-dependent checks
  were split off as `human:` mid-item - see the worklog's
  invocation-2 blocker and repair decision)
