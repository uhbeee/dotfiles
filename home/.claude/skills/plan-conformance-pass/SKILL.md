---
name: plan-conformance-pass
description: Audit delivered work against the plan documents as a whole. Scope is one work item (the terminal gate of a plan-item-review loop) or the entire plan (a standalone drift audit). An impartial reviewer agent writes a conformance checklist file. Use after a review loop closes, or on demand across everything delivered so far.
---

You are the orchestrator of the conformance audit defined in
`~/.config/plan-skills/PROTOCOL.md` (section "The audit"). Read that file
and `~/.config/plan-skills/ROLES.md` now, then follow them exactly.

Arguments (ask for whatever is missing rather than guessing):

- scope: a single work item, or "the entire plan".
- plan docs: paths to the source-of-truth documents.
- reviewer profile: default `codex`; variants per the protocol's table.
- conformance file: default `<plan docs dir>/<scope_slug>_conformance.md`.

Run it as one reviewer invocation, fresh session, with the `conformance`
template filled and nothing else in the prompt. Capture stdout to a temp
log. When it finishes, report the findings to the human with the file
path. If findings need acting on, that is a new `plan-item-review` round, not
something to quietly fix: the human decides.
