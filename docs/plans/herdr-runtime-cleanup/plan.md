# herdr runtime cleanup

> **Status:** approved 2026-09-13

## Intent

The devCheckout live-links mean herdr writes its runtime artifacts into
this checkout under `home/.config/herdr/` - logs, sockets,
`session.json`, `.plugins.lock`. They are gitignored, so the repo is
clean, but the working tree carries stale runtime junk. Remove what is
stale.

## Decisions

All from the 2026-09-13 discussion; final.

| # | Decision |
|---|----------|
| 1 | Deletion only: no `.gitignore` changes, no herdr config changes, no cleanup tooling or automation. |
| 2 | Only files the human has confirmed stale may be deleted. The confirmed-stale list is recorded as a `[decision]` in this plan's worklog before any deletion; runtime state can look abandoned while still being wanted, and that judgment is the human's alone. |
| 3 | Tracked and authored files (`home/.config/herdr/config.toml`) are untouchable. |
| 4 | Profiles: executor `claude`, implementation reviewer `codex`. |

## Scope

**In**

- Removing confirmed-stale runtime files under `home/.config/herdr/`.

**Out**

- Everything else: `.gitignore`, herdr configuration, any automation.

**Stretch**

- None.

## Risks

- **Deleting live state.** Severity: medium. A socket or session file
  may belong to a running or resumable herdr instance. Mitigation:
  decision 2's confirmed-list gate.

## Success criteria

- Every file on the confirmed-stale list is gone from
  `home/.config/herdr/`; nothing else under that directory changed;
  `git status` is unaffected.

## Open questions

- Which runtime files are currently stale (the human confirms;
  recorded as a worklog `[decision]` per decision 2).
