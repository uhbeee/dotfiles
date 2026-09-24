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

The steps: read plan.md, breakdown.md and the tail of worklog.md (a
[handoff] entry is the previous session's baton - do what it says
first); refuse to implement unless plan.md's status is approved; confirm
the next pending item whose blocking edges are all done with the user -
required input, so a plain question - offering a branch; append the
[session] boundary entry immediately before spawning the executor -
naming your own seat and profile at the run's first boundary, so the
worklog records who orchestrated - with the filled `executor` template
only
(work item, plan doc paths, review file, worklog), append the id entry
as soon as the CLI reports the session id, and capture stdout to a temp
log you name to the user, without tailing it; classify the exit per the
protocol (blocked and abnormal go to the user); on implemented, run the
item's validation line yourself, recording command and outcome as a
[validation] worklog entry whether it passed or not - red resumes the
executor with `executor-resume-validation` pointing at that entry,
three validation-red resumes on one item without green escalates to the
user, and `human:` validation lines go to the user, never to the
executor; when the exit criteria pass, run the
plan-item-review skill as the gate and then the plan-sync skill; and
write a [handoff] worklog entry at any natural stopping point. Never
commit, push, or open a PR on your own initiative - each takes the
user's explicit go, and a go for one is not a go for the next; on that
go you may commit, push the work branch and open the PR,
which you then leave open for them to review - merging takes their
separate word on that PR, after they have seen it (PROTOCOL.md,
"Seats").
