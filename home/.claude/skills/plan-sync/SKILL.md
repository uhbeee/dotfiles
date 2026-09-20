---
name: plan-sync
description: "Reconcile the plan documents with what actually landed: mark the work item done in the breakdown, record deviations, append to the worklog, republish the plan to the review surface. Use after a plan-item-review loop closes, or whenever the plan docs have drifted from reality."
---

You are the orchestrator. Read `~/.config/plan-skills/PROTOCOL.md` and
`~/.config/plan-skills/ARTIFACTS.md` now, then follow them exactly.

Arguments (ask for whatever is missing rather than guessing):

- plan directory (and optionally which work item just landed).

Steps:

1. **Establish what landed**: git log and diff since the last sync, the
   item's review file, and what the human confirmed. Do not take the
   session's memory of the work as the record; the repo is the record.
2. **breakdown.md**: set the item's status - `reviewed` while the
   human has not committed yet, `done <commit>` once the commit exists;
   never mark done without one. Note on the item where the
   implementation deviated from the drafted scope, and update the
   status header line.
3. **plan.md**: update Open questions that got answered and any current
   state the plan asserts that is no longer true. Anything that would
   contradict a Decision is the human's call to change, not yours -
   raise it instead of editing.
4. **worklog.md**: append `[decision]` entries for deviations not yet
   recorded. The `[done]` entry means landed - append it only when the
   commit exists, with the commit and verification. For a `reviewed`
   item, record the state as a `[handoff]` instead and finish the sync
   (status flip plus `[done]`) after the human commits.
5. **Republish** the plan with `plan-publish` per ARTIFACTS.md ("The
   review surface" - drain pending feedback first), and report what
   changed. The human owns the commit of the doc updates.
