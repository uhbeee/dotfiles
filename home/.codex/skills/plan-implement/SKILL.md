---
name: plan-implement
description: "Implement the next pending work item of an approved plan by spawning an executor seat, then gate it through plan-item-review and reconcile the docs with plan-sync. The orchestrator implements nothing itself. Reads the worklog tail to pick up where the last session stopped. Use when a plan directory exists and its plan is approved."
---

Implement the next pending work item of the plan named in the user's
request.

You are the orchestrator; you implement nothing. The loop is defined in
`~/.config/plan-skills/PROTOCOL.md` - read that file,
`~/.config/plan-skills/ROLES.md` and `~/.config/plan-skills/ARTIFACTS.md`
now, then follow them exactly, especially "The executor seat".

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
optionally which item). Executor/reviewer profiles come from plan.md's
Decisions table, overridable per run; plans without recorded profiles
fall back to executor `claude`, reviewer `codex`, stated at spawn time.
Executor and reviewer are never the same LLM. Ask for whatever is
missing rather than guessing.

The workspace step, inside herdr: establish the plan's home per
PROTOCOL.md "The plan workspace" before spawning anything, and never
open a second workspace for a plan that has one. One
`herdr worktree list --cwd <primary checkout>` lookup matched on the
work branch, then reuse, `herdr worktree open`, or `herdr worktree
create` on a surviving branch, as that section's arms direct. An open
workspace is not proof it still points at the checkout: if the branch
was renamed or the checkout moved, its recorded `checkout_path` is
stale, so re-open by branch to rebind it rather than trusting it -
passing the stale path as a seat's `--cwd` silently roots that seat
outside the repo instead of erring. At the plan's first item there is
nothing to recover, and this replaces the bare branch offer:

```bash
herdr worktree create --cwd <primary checkout> \
  --branch work/<slug> --base refs/heads/<default branch> \
  --label "<plan name>" --no-focus
```

Resolve the default branch as that section does - the primary
checkout's local `refs/heads/<default branch>`, taking only the branch
name from the remote HEAD, never the `origin/<name>` string
`git symbolic-ref` prints, which is a different commit whenever a fetch
is unmerged. Name the workspace and checkout to the user, set the
status token, and from here on run your own validation and diff
inspection in that checkout; the plan documents stay in the primary
checkout and are written there by absolute path, which for your codex
seats is what the writable root re-admits. Outside herdr none of this
applies: offer a plain branch as before.

The steps: read plan.md, breakdown.md and the tail of worklog.md (a
[handoff] entry is the previous session's baton - do what it says
first); refuse to implement unless plan.md's status is approved,
sending the user to plan-create's sign-off instead; confirm the next
pending item whose blocking edges are all satisfied with the user -
required input, so a plain question - where a blocking edge on a plan
with a worktree workspace is satisfied only once the blocker's
`done <commit>` exists and that commit is on the work branch
(`git merge-base --is-ancestor <commit> work/<slug>`), so a `reviewed`
blocker with no commit refuses the successor and the refusal goes to
the user, who owns the commit, while the classic single-checkout flow
keeps the unchanged rule of blocking edges `done`; take the workspace
step above before spawning anything; append the [session] boundary
entry immediately before spawning the executor - naming your own seat
and profile at the run's first boundary, so the worklog records who
orchestrated - with the filled `executor` template only (work item,
plan doc paths, review file, worklog); append the id entry as soon as
the CLI reports the session id, and wait for the invocation to end
without tailing it - headless, that is process exit with stdout
captured to a temp log you name to the user; hosted, it is the
settled-state wait, and the pane transcript is the record, so no log
path is reported; classify the exit per the protocol (blocked and
abnormal go to the user); on implemented, run the item's validation
line yourself, in the plan checkout when the plan has a worktree
workspace, recording command and outcome as a [validation] worklog
entry whether it passed or not - red resumes the executor with
`executor-resume-validation` pointing at that entry, three
validation-red resumes on one item without green escalates to the
user, and `human:` validation lines go to the user, never to the
executor; when the exit criteria pass, run the plan-item-review skill
as the gate and then the plan-sync skill; and write a [handoff]
worklog entry at any natural stopping point - the plan workspace is
the plan's home and survives the pause, so leave it open, with a
status token the next invocation can read, and say in the [handoff]
which branch it is on, since tearing it down is plan-sync's gated step
or the user's [decision] to abandon the plan, never a stopping-point
tidy-up.

Never commit, push, or open a PR on your own initiative - each takes
the user's explicit go, and a go for one is not a go for the next; on
that go you may commit, push the work branch and open the PR, which
you then leave open for them to review - merging takes their separate
word on that PR, after they have seen it (PROTOCOL.md, "Seats").
