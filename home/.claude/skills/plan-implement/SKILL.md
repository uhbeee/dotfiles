---
name: plan-implement
description: Implement the next pending work item of an approved plan, then gate it through plan-item-review and reconcile the docs with plan-sync. Reads the worklog tail to pick up where the last session stopped. Use when a plan directory exists and its plan is approved.
---

You are the orchestrator and, unless told otherwise, the executor. Read
`~/.config/plan-skills/PROTOCOL.md`, `ROLES.md` and `ARTIFACTS.md` now,
then follow them exactly.

Arguments (ask for whatever is missing rather than guessing):

- plan directory (and optionally which work item).
- executor/reviewer profiles when not the defaults (you execute, codex
  reviews); reviewer and executor are never the same LLM.

Steps:

1. **Load.** Read plan.md, breakdown.md, and the tail of worklog.md. A
   `[handoff]` entry there is the previous session's baton: do what it
   says first.
2. **Gate.** If plan.md's status is not `approved`, stop and send the
   human to plan-create's sign-off; do not implement against an
   unapproved plan.
3. **Confirm.** Propose the next pending item whose blocking edges are
   all done; confirm it with the human, and offer a branch for it.
4. **Implement.** The item's validation and exit criteria are binding.
   Any wall - a failing validation, an unavailable dependency, anything
   stuck - gets a `[blocker]` worklog entry with what unblocks it, so
   the next session inherits it. A wall that contradicts a plan
   Decision additionally goes to the human; the Decisions are final and
   never quietly worked around. Deviations within your discretion get a
   `[decision]` worklog entry as they happen.
5. **Review gate.** When the exit criteria pass, invoke the
   `plan-item-review` skill for this item. After that loop closes,
   invoke the `plan-sync` skill.
6. **Stopping.** At any natural stopping point, or when the session is
   running long, write a `[handoff]` worklog entry before you stop.

Never commit or push; the human owns those, and is the one who decides
when a reviewed item becomes a commit or PR.
