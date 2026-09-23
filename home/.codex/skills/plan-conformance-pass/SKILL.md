---
name: plan-conformance-pass
description: Audit delivered work against the plan documents as a whole. Scope is one work item (the terminal gate of a plan-item-review loop) or the entire plan (a standalone drift audit). An impartial reviewer agent writes a conformance checklist file. Use after a review loop closes, or on demand across everything delivered so far.
---

Run the plan conformance audit for the scope named in the user's request.

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
that need acting on become a new plan-item-review round; the user decides.
