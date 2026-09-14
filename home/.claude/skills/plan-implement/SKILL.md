---
name: plan-implement
description: "Implement the next pending work item of an approved plan by spawning an executor seat, then gate it through plan-item-review and reconcile the docs with plan-sync. The orchestrator implements nothing itself. Reads the worklog tail to pick up where the last session stopped. Use when a plan directory exists and its plan is approved."
---

You are the orchestrator; you implement nothing. Read
`~/.config/plan-skills/PROTOCOL.md`, `ROLES.md` and `ARTIFACTS.md` now,
then follow them exactly - especially "The executor seat".

Arguments (ask for whatever is missing rather than guessing):

- plan directory (and optionally which work item).
- executor/reviewer profiles: from plan.md's Decisions table; per-run
  override allowed; plans without recorded profiles fall back to
  executor `claude`, reviewer `codex`, stated at spawn time. Executor
  and reviewer are never the same LLM.

Steps:

1. **Load.** Read plan.md, breakdown.md, and the tail of worklog.md. A
   `[handoff]` entry there is the previous session's baton: do what it
   says first.
2. **Gate.** If plan.md's status is not `approved`, stop and send the
   human to plan-create's sign-off; do not implement against an
   unapproved plan.
3. **Confirm.** Propose the next pending item whose blocking edges are
   all done; confirm it with the human, and offer a branch for it.
4. **Spawn.** Fill the `executor` template - work item, plan doc paths,
   review file path, worklog path - and spawn it per the executor
   profile (executor grants, per the protocol's profile table). Append
   the `[session]` boundary entry immediately before the spawn, and the
   id entry as soon as the CLI reports the session id. Capture stdout
   to a temp log you name to the human. Do not tail it; wait for exit.
5. **Judge.** Classify the exit per PROTOCOL.md ("The executor seat"):
   blocked and abnormal go to the human. On implemented, run the item's
   validation line yourself; red means append the evidence to the
   worklog and resume the executor with `executor-resume-validation` -
   three validation-red resumes on one item without green escalates to
   the human; `human:` validation lines go to the human at the pause,
   never to the executor.
6. **Review gate.** When the exit criteria pass, invoke the
   `plan-item-review` skill for this item. After that loop closes,
   invoke the `plan-sync` skill.
7. **Stopping.** At any natural stopping point, or when the session is
   running long, write a `[handoff]` worklog entry before you stop.

Never commit or push; the human owns those, and is the one who decides
when a reviewed item becomes a commit or PR.
