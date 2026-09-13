---
name: plan-archive
description: "Move a finished plan's directory into an archive repo: verify the plan is terminal, stamp provenance, file it under <repo>/<plan>/, index it, and leave a one-line tombstone behind. Use when a plan's work is done and the plan should leave the working repo."
---

You are the orchestrator. Read `~/.config/plan-skills/ARTIFACTS.md`
("Archival") now, then follow it exactly. No reviewer seat is involved.

Arguments (ask for whatever is missing rather than guessing):

- plan directory.
- archive repo: default is the path in
  `~/.config/dotfiles-local/plan-archive-root`; an explicit argument
  overrides it. If neither exists, ask.

Steps:

1. **Gate.** Verify the plan is terminal: every breakdown item
   `done <commit>`, latest conformance file fully closed. Anything
   short of that goes to the human; archiving anyway is their call,
   recorded first as a `[decision]` worklog entry.
2. **Stamp.** Write `ARCHIVED.md` into the plan directory per
   ARTIFACTS.md: source repo path and remote, the items' commit range,
   created / approved / archived dates, outcome against the plan's
   Intent, and the plan-skills core version.
3. **Move.** The destination is
   `<archive repo>/<source repo name>/<plan_name_slug>/`. If it already
   exists, stop and ask - the archive is append-only, and nothing is
   copied, overwritten, or removed until the human resolves the
   collision. Otherwise copy the plan directory there, append one index
   line to the archive repo's README.md, and verify the copy is
   complete before touching the source.
4. **Tombstone.** Append the one-line pointer to the source repo's
   `docs/plans/ARCHIVE.md` and remove the plan directory.
5. **Report** both sides. The human owns the commit in each repo;
   remind them the move is not durable until both are committed.
