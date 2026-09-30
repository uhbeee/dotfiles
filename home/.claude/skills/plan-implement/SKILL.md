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
   all satisfied; confirm it with the human. A blocking edge on a plan
   with a worktree workspace is satisfied only when the blocker's
   `done <commit>` exists and that commit is on the plan branch
   (`git merge-base --is-ancestor <commit> plan/<slug>`); a `reviewed`
   blocker with no commit refuses the successor, and the refusal goes
   to the human, who owns the commit. In the classic single-checkout
   flow the rule is unchanged: blocking edges `done`.
4. **Workspace.** Inside herdr, establish the plan's home per
   PROTOCOL.md "The plan workspace" before spawning anything: one
   `herdr worktree list --cwd <primary checkout>` lookup by plan
   branch, then reuse, `worktree open`, or `worktree create` on a
   surviving branch. At the plan's first item there is nothing to
   recover, and this replaces the bare branch offer:

   ```bash
   herdr worktree create --cwd <primary checkout> \
     --branch plan/<slug> --base refs/heads/<default branch> \
     --label "<plan name>" --no-focus
   ```

   Resolve the default branch as that section does - the primary
   checkout's local `refs/heads/<default branch>`, taking only the
   branch name from the remote HEAD, never the `origin/<name>` string
   `git symbolic-ref` prints, which is a different commit whenever a
   fetch is unmerged.
   Name the workspace and checkout to the human, set the status token,
   and from here on run your own validation and diff inspection in
   that checkout; the plan documents stay in the primary checkout and
   are written there by absolute path. Outside herdr, offer a plain
   branch as before.
5. **Spawn.** Fill the `executor` template - work item, plan doc paths,
   review file path, worklog path - and spawn it per the executor
   profile (executor grants, per the protocol's profile table). Append
   the `[session]` boundary entry immediately before the spawn, and the
   id entry as soon as the CLI reports the session id. Wait for the
   invocation to end without tailing it: headless, that is process exit
   with stdout captured to a temp log you name to the human; hosted,
   it is the settled-state wait, and the pane transcript is the record.
6. **Judge.** Classify the exit per PROTOCOL.md ("The executor seat"):
   blocked and abnormal go to the human. On implemented, run the item's
   validation line yourself; red means append the evidence to the
   worklog and resume the executor with `executor-resume-validation` -
   three validation-red resumes on one item without green escalates to
   the human; `human:` validation lines go to the human at the pause,
   never to the executor.
7. **Review gate.** When the exit criteria pass, invoke the
   `plan-item-review` skill for this item. After that loop closes,
   invoke the `plan-sync` skill.
8. **Stopping.** At any natural stopping point, or when the session is
   running long, write a `[handoff]` worklog entry before you stop. The
   plan workspace is the plan's home and survives the pause: leave it
   open, with a status token the next invocation can read, and say in
   the `[handoff]` which branch it is on. Tearing it down is
   plan-sync's gated step, or the human's `[decision]` to abandon the
   plan - never a stopping-point tidy-up.

Never commit or push; the human owns those, and is the one who decides
when a reviewed item becomes a commit or PR.
