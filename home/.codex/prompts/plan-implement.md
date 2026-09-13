Implement the next pending work item of the plan named in the arguments:
$ARGUMENTS

You are the orchestrator and, unless told otherwise, the executor of the
loop defined in `~/.config/plan-skills/PROTOCOL.md`. Read that file,
`~/.config/plan-skills/ROLES.md` and `~/.config/plan-skills/ARTIFACTS.md`
now, then follow them exactly.

You need from the arguments or the user: the plan directory (and
optionally which item), plus the reviewer profile (a different LLM from
you when you are executing: default `claude`). Ask for whatever is
missing rather than guessing.

The steps: read plan.md, breakdown.md and the tail of worklog.md (a
[handoff] entry is the previous session's baton - do what it says
first); refuse to implement unless plan.md's status is approved; confirm
the next pending item whose blocking edges are all done with the user,
offering a branch; implement with the item's validation and exit
criteria binding, recording [decision] worklog entries for deviations
and a [blocker] entry (with what unblocks it) for any wall - one that
contradicts a plan Decision additionally goes to the user, never a
quiet workaround; when the exit criteria pass, run the plan-item-review prompt
as the gate and then the plan-sync prompt; and write a [handoff] worklog
entry at any natural stopping point. Never commit or push; the user owns
those.
