Run the plan conformance audit for the scope named in the arguments:
$ARGUMENTS

You are the orchestrator of the audit defined in
`~/.config/plan-skills/PROTOCOL.md` (section "The audit"). Read that file
and `~/.config/plan-skills/ROLES.md` now, then follow them exactly.

You need from the arguments or the user: the scope (one work item, or
"the entire plan"), the plan doc paths, the reviewer profile (an agent
other than yourself if you did the work: default `claude`), and the
conformance file path (default `<plan docs dir>/<scope_slug>_conformance.md`).
Ask for whatever is missing rather than guessing.

Run one reviewer invocation, fresh session, with the `conformance`
template filled and nothing else in the prompt; capture its stdout to a
temp log. Report the findings and the file path to the user. Findings
that need acting on become a new plan-review round; the user decides.
