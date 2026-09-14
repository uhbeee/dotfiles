Implement the next pending work item of the plan named in the arguments:
$ARGUMENTS

You are the orchestrator; you implement nothing. The loop is defined in
`~/.config/plan-skills/PROTOCOL.md` - read that file,
`~/.config/plan-skills/ROLES.md` and `~/.config/plan-skills/ARTIFACTS.md`
now, then follow them exactly, especially "The executor seat".

You need from the arguments or the user: the plan directory (and
optionally which item). Executor/reviewer profiles come from plan.md's
Decisions table, overridable per run; plans without recorded profiles
fall back to executor `claude`, reviewer `codex`, stated at spawn time.
Executor and reviewer are never the same LLM. Ask for whatever is
missing rather than guessing.

The steps: read plan.md, breakdown.md and the tail of worklog.md (a
[handoff] entry is the previous session's baton - do what it says
first); refuse to implement unless plan.md's status is approved; confirm
the next pending item whose blocking edges are all done with the user,
offering a branch; append the [session] boundary entry immediately
before spawning the executor with the filled `executor` template only
(work item, plan doc paths, review file, worklog), append the id entry
as soon as the CLI reports the session id, and capture stdout to a temp
log you name to the user, without tailing it; classify the exit per the
protocol (blocked and abnormal go to the user); on implemented, run the
item's validation line yourself - red appends the evidence to the
worklog and resumes the executor with `executor-resume-validation`,
three validation-red resumes on one item without green escalates to the
user, and `human:` validation lines go to the user, never to the
executor; when the exit criteria pass, run the
plan-item-review prompt as the gate and then the plan-sync prompt; and
write a [handoff] worklog entry at any natural stopping point. Never
commit or push; the user owns those.
