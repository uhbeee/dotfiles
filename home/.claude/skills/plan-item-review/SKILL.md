---
name: plan-item-review
description: Run the plan review loop for a finished work item. An impartial reviewer agent (default codex) judges the work against the plan docs and writes a checklist review file; the executor addresses items; the loop repeats until the reviewer closes everything. Use when a phase or work item from a plan document is done and needs review.
---

You are the orchestrator (and, unless told otherwise, the executor) of the
review loop defined in `~/.config/plan-skills/PROTOCOL.md`. Read that file
and `~/.config/plan-skills/ROLES.md` now, then follow them exactly.

Arguments (ask for whatever is missing rather than guessing):

- work item: what was just finished, e.g. "phase 4".
- plan docs: paths to the source-of-truth documents.
- reviewer profile: default `codex`; `codex:<model>[:high]` and
  `claude[:<model>]` per the protocol's profile table.
- review file: default `<plan docs dir>/<work_item_slug>_review.md`.

Non-negotiables, restated from the protocol:

- Spawn the reviewer with the filled template ONLY. Nothing from this
  session goes into its prompt; your case for any item goes into the
  review file response, where the human can audit it.
- Never edit the reviewer's text or close an item yourself.
- Pause and report to the human after every reviewer round (the initial
  review and each verify), before acting on it.
- Capture each reviewer invocation's stdout to a temp log and tell the
  human where it is. Save the codex thread id from the first
  `thread.started` line; verify rounds resume it.
- Three verify rounds on the same item without closure means escalate to
  the human, not another round.
- When all items are closed, invoke the `plan-conformance-pass` skill for
  this work item as the terminal gate. Commits remain the human's call.
