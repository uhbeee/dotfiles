Run the plan review loop for the work item named in the arguments:
$ARGUMENTS

You are the orchestrator (and, unless told otherwise, the executor) of
the review loop defined in `~/.config/plan-skills/PROTOCOL.md`. Read that
file and `~/.config/plan-skills/ROLES.md` now, then follow them exactly.

You need from the arguments or the user: the work item, the plan doc
paths, the reviewer profile (when you are executing, the reviewer must be
a different agent: default `claude`, see the protocol's profile table),
and the review file path (default `<plan docs dir>/<work_item_slug>_review.md`).
Ask for whatever is missing rather than guessing.

Non-negotiables, restated from the protocol: the reviewer is spawned with
the filled template only, never with your session context; you never
close an item or edit reviewer text; you pause and report to the user
after every reviewer round before acting on it; reviewer stdout goes to a
temp log you name to the user; three verify rounds without closure on an
item means escalate to the user; when all items close, run the
plan-conformance-pass prompt as the terminal gate. Commits are the
user's call.
