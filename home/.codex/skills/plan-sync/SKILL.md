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

The steps: establish what landed from git history, the item's review
file and the user's confirmation, asked plainly since you need it (the
repo is the record, not your session memory); update breakdown.md (item
status - `reviewed` until
the user's commit exists, `done <commit>` only once it does - plus
deviations and the status header line); update plan.md's answered Open
questions and stale current state - recording an answer is your work,
while adding, dropping or rewording the questions after approval takes
a [decision] - raising rather than editing anything that would
contradict a Decision; append [decision] entries for
deviations, and a [done] entry only when the commit exists (a reviewed
item gets a [handoff] instead, and the sync finishes after the user
commits); republish the plan with `plan-publish` per ARTIFACTS.md
("The review surface" - drain pending feedback first); and report what
changed. The user owns every commit.
