---
name: plan-item-review
description: Run the plan review loop for a finished work item. An impartial reviewer agent (default codex) judges the work against the plan docs and writes a checklist review file; a spawned executor seat addresses items; the loop repeats until the reviewer closes everything. Use when a phase or work item from a plan document is done and needs review.
---

Run the plan review loop for the work item named in the user's request.

You are the orchestrator of the review loop defined in
`~/.config/plan-skills/PROTOCOL.md`; you implement nothing. Read that
file, `~/.config/plan-skills/ROLES.md` and
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

You need from the arguments or the user: the work item, the plan doc
paths, and the review file path (default
`<plan docs dir>/<work_item_slug>_review.md`). Executor/reviewer
profiles come from plan.md's Decisions table when the item belongs to a
plan, overridable per run; fallbacks executor `claude`, reviewer
`codex`; never the same LLM as each other. Ask for whatever is missing
rather than guessing.

When the item belongs to a plan with a worktree workspace, every seat
of this loop - the reviewer, the executor it resumes, and the
conformance seat - is hosted there, per PROTOCOL.md "The plan
workspace": locate the workspace by the work branch and reuse, open or
recreate it as that section's arms direct, since a review invoked on
its own may be the first thing to touch the plan this session; split
each seat's pane from the workspace's pane with the plan checkout as
cwd; and never open a second workspace for the review. The review file
and worklog stay in the plan directory in the primary checkout, which
is what the codex writable root re-admits. Advance the workspace status
token at each round and pause so the panel shows where the loop is.

Non-negotiables, restated from the protocol: every seat is spawned with
its filled template only, never with your session context, and the
executor's case for an item goes into its review-file response, where
the user can audit it, rather than into anyone's prompt; ADDRESS is
the executor's - resume the item's executor session from its latest
[session] id entry whose seat is executor, never a reviewer's id entry
from the same worklog, with the `executor-address` template, fresh
spawn (full `executor` template) only if the session is lost or the
profile changed, the [session] boundary entry appended immediately
before and the id entry when the CLI reports it - after the seat's
terminal entry for `claude -p`, which reports ids only at exit; record
it then rather than back-dating it (and name your own seat and profile
at the run's first boundary when this skill runs standalone), and
standalone reviews without a plan worklog get one named with the user
first, asked plainly; after ADDRESS and before any VERIFY round you
apply the protocol's GATE step - classify the ADDRESS exit (blocked
and abnormal go to the user) and re-run the item's validation line
after every implemented exit, unconditionally, red following the
validation gate, never a reviewer round, and run that validation where
the work is: the plan checkout when the plan has a worktree workspace;
you never close an item or edit reviewer text; you pause and report to
the user after every reviewer round before acting on it; you record
how to reach each seat invocation again - headless, its stdout goes to
a temp log you name to the user; hosted, the pane transcript is the
record (`herdr agent read`, `--source visible` unless the seat is
settled idle) and the live agent is its own continuity, so a later
round is another prompt to the same name - and every seat including
the reviewer gets the full [session] pair - boundary before each spawn
or resume, id entry as soon as the id is known - and verify rounds
resume that reviewer's own id entry; three verify rounds without
closure on an item means escalate to the user; when all items close,
run the plan-conformance-pass skill as the terminal gate. Commits are
the user's call.
