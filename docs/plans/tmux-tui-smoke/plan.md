# tmux for the TUI smoke

> **Status:** approved 2026-09-13

## Intent

tests/pi-calm.test.sh proves the Calm extension in a real TUI, but only
when tmux is on PATH; without it the smoke silently skips
(tests/pi-calm.test.sh:606-607). The library should provide tmux so the
proof runs wherever the library is consumed.

## Decisions

All from the 2026-09-13 discussion; final.

| # | Decision |
|---|----------|
| 1 | tmux comes from nixpkgs through the exported home configuration; never homebrew. |
| 2 | Bare package only: no `programs.tmux` module, no tmux dotfiles. |
| 3 | Placement follows repo precedent and is the implementer's call: the general CLI list (`lib/base-packages.nix`) or tool-adjacent (`modules/home/common/pi.nix`, cf. its nodejs declaration), with a rationale comment in repo style. |
| 4 | Profiles: executor `claude`, implementation reviewer `codex`. |

## Scope

**In**

- The package declaration and its rationale comment.

**Out**

- tmux configuration of any kind.
- Changes to the tests.
- Homebrew.

**Stretch**

- None.

## Risks

- **Package-set eval breakage.** Severity: low. Mitigation:
  `tests/consumer-probe.test.sh` builds two consumer configurations and
  must stay green.

## Success criteria

- tmux is declared in exactly one place in the exported library, and the
  pi-calm TUI smoke no longer skips for a lack of tmux.

## Open questions

- None.
