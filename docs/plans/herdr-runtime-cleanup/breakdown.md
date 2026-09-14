# herdr runtime cleanup - breakdown

> **Status:** 1/1 items done; last synced 2026-09-13 (docs-only plan, landed with the plan-docs commit)

## Item 1: Remove confirmed-stale herdr runtime artifacts

- **Goal:** Delete from `home/.config/herdr/` exactly the files the
  worklog's confirmed-stale `[decision]` lists (plan decisions 1-3).
- **Blocking edges:** none.
- **Validation:** every file named on the worklog's confirmed-stale
  `[decision]` list is absent from `home/.config/herdr/`;
  `git status --short home/.config/herdr/` prints nothing.
- **Exit criteria:** Confirmed-stale files deleted; nothing else under
  `home/.config/herdr/` touched; no tracked file changed.
- **Status:** done (review and conformance clean 2026-09-13; the
  deletions touched only untracked files, so there is no code commit -
  the plan docs land as the item's record in the plan-docs commit, its
  hash in the worklog's final entry)
