---
name: plan-sync
description: "Reconcile the plan documents with what actually landed: mark the work item done in the breakdown, record deviations, append to the worklog, republish the artifact. Use after a plan-item-review loop closes, or whenever the plan docs have drifted from reality."
---

You are the orchestrator. Read `~/.config/plan-skills/PROTOCOL.md` and
`~/.config/plan-skills/ARTIFACTS.md` now, then follow them exactly.

Arguments (ask for whatever is missing rather than guessing):

- plan directory (and optionally which work item just landed).

Steps:

1. **Establish what landed**: git log and diff since the last sync, the
   item's review file, and what the human confirmed. Do not take the
   session's memory of the work as the record; the repo is the record.
   For a plan with a worktree workspace, the plan checkout on the plan
   branch is where you read the log and the diff.
2. **breakdown.md**: set the item's status - `reviewed` while the
   human has not committed yet, `done <commit>` once the commit exists;
   never mark done without one. On a plan with a worktree workspace
   that commit is the plan-branch commit that delivered the item,
   identified with the human (one item can land as more than one
   commit, and the plan branch carries other items' commits too);
   confirm it is on the branch with
   `git merge-base --is-ancestor <commit> plan/<slug>` before writing
   it, because that is exactly what a successor's blocking edge will
   check. In the classic single-checkout flow the rule is unchanged.
   Note on the item where the implementation deviated from the drafted
   scope, and update the status header line.
3. **plan.md**: update Open questions that got answered and any current
   state the plan asserts that is no longer true. Anything that would
   contradict a Decision is the human's call to change, not yours -
   raise it instead of editing.
4. **worklog.md**: append `[decision]` entries for deviations not yet
   recorded. The `[done]` entry means landed - append it only when the
   commit exists, with the commit and verification. For a `reviewed`
   item, record the state as a `[handoff]` instead and finish the sync
   (status flip plus `[done]`) after the human commits.
5. **Workspace**, for a plan with a worktree workspace: set the status
   token to where the plan now stands (`reviewed - awaiting commit`,
   the next item, or `done`), then evaluate the teardown gate of
   PROTOCOL.md "The plan workspace" - every item `done <commit>` AND
   the plan branch tip contained in the primary checkout's local
   default branch (`refs/heads/<default branch>`, resolved as that
   section directs; testing the remote-tracking ref instead asks about
   fetched remote history, not the human's merge). Short of both, say
   so and leave the workspace open; that is the normal outcome of a
   mid-plan sync. When both hold, confirm with the human that the plan
   is finished, that every seat has settled and its pane is closed,
   and that the checkout is clean, then
   `herdr worktree remove --workspace <workspace-id>`; the branch
   survives. Abandonment is the human's `[decision]`, never yours, and
   `--force` over a dirty checkout needs their explicit word.
6. **Republish** the plan artifact per ARTIFACTS.md, and report what
   changed. The human owns the commit of the doc updates.
