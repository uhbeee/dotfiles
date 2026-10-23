---
name: plan-sync
description: "Reconcile the plan documents with what actually landed: mark the work item done in the breakdown, record deviations, append to the worklog, republish the plan to the review surface. Use after a plan-item-review loop closes, or whenever the plan docs have drifted from reality."
---

Reconcile the plan documents named in the user's request with what
actually landed in the repository.

You are the orchestrator. Read `~/.config/plan-skills/PROTOCOL.md` and
`~/.config/plan-skills/ARTIFACTS.md` now, then follow them exactly.

Asking in codex: its collaboration-mode rules come first, and a skill
does not override them. This skill writes files, so it runs in Default
mode, where `request_user_input` is for optional questions whose answer
would materially improve the work - one to three per call, prefer one,
every question carrying concrete options with your recommendation
marked - and an empty return means carry on with your best judgment
rather than ask again. Anything you actually need before you can
continue is not that kind of question: ask it as one concise plain-text
question and wait, never as options typed into a message, and never
route a permission ask through the tool. What no mode changes: the
answers below are the user's, so a missing one is asked for, never
assumed.

You need from the arguments or the user: the plan directory (and
optionally which work item just landed). Ask rather than guess.

The steps: establish what landed from git log and diff since the last
sync, the item's review file and the user's confirmation, asked
plainly since you need it (the repo is the record, not your session
memory) - and for a plan with a worktree workspace the plan checkout
on the work branch is where you
read the log and the diff; update breakdown.md (item status -
`reviewed` until the user's commit exists, `done <commit>` only once it
does, and on a plan with a worktree workspace that commit is the
work-branch commit that delivered the item, identified with the user,
since one item can land as more than one commit and the work branch
carries other items' commits too - confirm it is on the branch with
`git merge-base --is-ancestor <commit> work/<slug>` before writing it,
because that is exactly what a successor's blocking edge will check,
while the classic single-checkout flow keeps the unchanged rule - plus
deviations and the status header line); update plan.md's answered Open
questions and stale current state - recording an answer is your work,
while adding, dropping or rewording the questions after approval takes
a [decision] - raising rather than editing anything that would
contradict a Decision; and append to worklog.md: [decision] entries
for deviations, and a [done] entry only when the commit exists (a
reviewed item gets a [handoff] instead, and the sync finishes after
the user commits).

Then the workspace step, for a plan with a worktree workspace: set the
status token to where the plan now stands (`reviewed - awaiting
commit`, the next item, or `done`), then evaluate the teardown gate of
PROTOCOL.md "The plan workspace" - every item `done <commit>` AND the
work branch tip contained in the primary checkout's local default
branch (`refs/heads/<default branch>`, resolved as that section
directs, since testing the remote-tracking ref instead asks about
fetched remote history rather than the user's merge). Short of both,
say so and leave the workspace open; that is the normal outcome of a
mid-plan sync. When both hold, confirm with the user that the plan is
finished, that every seat has settled and that no pane in the
workspace is running anything - the hazard `worktree remove` poses is
a live process, not an open pane, and
`herdr pane process-info --pane <pane-id>` over the panes
`herdr pane list --workspace <workspace-id>` returns is the check -
and that the checkout is clean, then
`herdr worktree remove --workspace <workspace-id>`; the branch
survives. A workspace already closed under you (the lost-anchor case
that section documents) is reopened with
`herdr worktree open --branch work/<slug> --no-focus` and removed by
the id that returns. Abandonment is the user's [decision], never
yours, and `--force` over a dirty checkout needs their explicit word.

Finally the republish, which happens only if the plan's surface is in
use: drain pending feedback first, per ARTIFACTS.md ("The review
surface"), and that poll runs on every sync whatever the surface - on
a chat-reviewed plan it normally reports the session unavailable,
which is its expected reading there. Then read plan.md's
`Review surface:` header field: on `lavish`, republish the plan with
`plan-publish` exactly as before; on `chat`, skip the publish; an
absent or unrecognized value publishes, because the field is an
opt-out and no plan silently loses a surface its user wants. Say at
the pause when you skipped the publish and which field value caused
it, and report what changed. The user owns every commit.
