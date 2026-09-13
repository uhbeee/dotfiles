Reconcile the plan documents named in the arguments with what actually
landed in the repository:
$ARGUMENTS

You are the orchestrator. Read `~/.config/plan-skills/PROTOCOL.md` and
`~/.config/plan-skills/ARTIFACTS.md` now, then follow them exactly.

You need from the arguments or the user: the plan directory (and
optionally which work item just landed). Ask rather than guess.

The steps: establish what landed from git history, the item's review
file and the user's confirmation (the repo is the record, not your
session memory); update breakdown.md (item status - `reviewed` until
the user's commit exists, `done <commit>` only once it does - plus
deviations and the status header line); update plan.md's answered Open
questions and stale current state, raising rather than editing anything
that would contradict a Decision; append [decision] entries for
deviations, and a [done] entry only when the commit exists (a reviewed
item gets a [handoff] instead, and the sync finishes after the user
commits); and report what changed. The user owns every commit.
