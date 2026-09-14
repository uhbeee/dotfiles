Run the plan review loop for the work item named in the arguments:
$ARGUMENTS

You are the orchestrator of the review loop defined in
`~/.config/plan-skills/PROTOCOL.md`; you implement nothing. Read that
file, `~/.config/plan-skills/ROLES.md` and
`~/.config/plan-skills/ARTIFACTS.md` now, then follow them exactly.

You need from the arguments or the user: the work item, the plan doc
paths, and the review file path (default
`<plan docs dir>/<work_item_slug>_review.md`). Executor/reviewer
profiles come from plan.md's Decisions table when the item belongs to a
plan, overridable per run; fallbacks executor `claude`, reviewer
`codex`; never the same LLM as each other. Ask for whatever is missing
rather than guessing.

Non-negotiables, restated from the protocol: every seat is spawned with
its filled template only, never with your session context; ADDRESS is
the executor's - resume the item's executor session from its latest
[session] id entry with the `executor-address` template, fresh spawn
(full `executor` template) only if the session is lost or the profile
changed, the [session] boundary entry appended immediately before and
the id entry when the CLI reports it, and standalone reviews without a
plan worklog get one named with the user first; after ADDRESS and
before any VERIFY round you apply the protocol's GATE step - classify
the ADDRESS exit (blocked and abnormal go to the user) and re-run the
item's validation line after every implemented exit, unconditionally,
red following the validation gate, never a reviewer round; you never
close an item
or edit reviewer text; you pause and report to the user after every
reviewer round before acting on it; every seat's stdout goes to a temp
log you name to the user; three verify rounds without closure on an
item means escalate to the user; when all items close, run the
plan-conformance-pass prompt as the terminal gate. Commits are the
user's call.
