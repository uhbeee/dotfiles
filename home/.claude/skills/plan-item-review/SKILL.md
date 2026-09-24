---
name: plan-item-review
description: Run the plan review loop for a finished work item. An impartial reviewer agent (default codex) judges the work against the plan docs and writes a checklist review file; a spawned executor seat addresses items; the loop repeats until the reviewer closes everything. Use when a phase or work item from a plan document is done and needs review.
---

You are the orchestrator of the review loop defined in
`~/.config/plan-skills/PROTOCOL.md`; you implement nothing. Read that
file, `~/.config/plan-skills/ROLES.md` and
`~/.config/plan-skills/ARTIFACTS.md` now, then follow them exactly.

Arguments (ask for whatever is missing rather than guessing):

- work item: what was just finished, e.g. "phase 4".
- plan docs: paths to the source-of-truth documents.
- executor/reviewer profiles: from plan.md's Decisions table when the
  item belongs to a plan, overridable per run; fallbacks executor
  `claude`, reviewer `codex`. Never the same LLM as each other.
- review file: default `<plan docs dir>/<work_item_slug>_review.md`.

Non-negotiables, restated from the protocol:

- Spawn every seat with its filled template ONLY. Nothing from this
  session goes into any seat's prompt; the executor's case for an item
  goes into the review file response, where the human can audit it.
- ADDRESS is the executor's: resume the item's executor session (its
  latest `[session]` id entry whose seat is executor - reviewer ids
  live in the same worklog and resuming one here would put the review
  seat on the executor's work) with the `executor-address` template; a
  fresh spawn (full `executor` template) only if the session is lost
  or the profile changed. Either way, append the `[session]` boundary
  entry immediately before, and the id entry when the CLI reports it,
  which for `claude -p` is after that seat's terminal entry - record it
  then, honestly, and never back-date one to look earlier. Verify
  rounds resume the reviewer's own latest id entry, not the item's
  latest. When this skill runs standalone, name your own seat and
  profile at the first boundary.
  For standalone reviews with no plan worklog, name a worklog file
  with the human first - the executor seat needs one.
- After ADDRESS and before any VERIFY round, apply the protocol's GATE
  step: classify the ADDRESS exit (blocked and abnormal go to the
  human) and re-run the item's validation line after every implemented
  exit, unconditionally - red follows the validation gate (evidence,
  resume, cap), never a reviewer round.
- Never edit the reviewer's text or close an item yourself.
- Pause and report to the human after every reviewer round (the initial
  review and each verify), before acting on it.
- Capture each seat invocation's stdout to a temp log and tell the
  human where it is. The reviewer seat gets the same `[session]` record
  as the executor, not a mention in passing: a boundary entry before
  every spawn and resume, and an id entry when the CLI reports the id -
  the codex `thread.started` line, or the claude `session_id` - which
  later rounds resume from. With `claude -p` that id arrives at exit,
  so its entry lands after the seat's terminal entry: write it then,
  and never back-date one to look earlier.
- Three verify rounds on the same item without closure means escalate to
  the human, not another round.
- When all items are closed, invoke the `plan-conformance-pass` skill for
  this work item as the terminal gate. Commits remain the human's call.
