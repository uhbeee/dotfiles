# plan-skills protocol

A review loop between AI agents that never talk to each other directly.
All communication goes through one markdown review file the human can audit
at any point. The plan documents, not anyone's session memory, are the
source of truth for what the work should be.

Two entry points share this protocol: `plan-review` (the loop) and
`plan-conformance-pass` (the terminal audit). Role prompt templates live in
ROLES.md next to this file.

## Seats

- **Orchestrator**: the agent the human is talking to. Drives the loop,
  spawns the other seats as fresh CLI processes (profiles below), and
  pauses for the human at the marked points. By default it doubles as
  executor.
- **Executor**: does the work. Addresses review items by fixing the work,
  then appending a response under each item. Never marks an item closed.
- **Reviewer**: judges the work against the plan docs. Writes the review
  checklist, verifies fixes, and is the only seat that closes items.

Hard rules, regardless of who fills which seat:

- Reviewer and executor are never the same agent session, and never the
  same underlying LLM. Before starting, the orchestrator establishes
  which model fills each seat (including its own, when it doubles as
  executor, and every panel member's) and stops to ask the human if a
  selection would put the same model in both seats.
- The reviewer receives ONLY its role prompt with the placeholders filled:
  plan doc paths, the review file path, the working tree. Never the
  executor's or orchestrator's session context, summaries, or chat. The
  executor's case lives in the review file responses or nowhere.
- No seat communicates with another except through the review file.
- The human gates everything at the pause points and owns commits.

## The review file

- Default path: `<plan docs dir>/<work_item_slug>_review.md` (conformance:
  `<scope_slug>_conformance.md`).
- The reviewer owns the file's structure: a markdown checklist, one
  `- [ ]` item per issue, concrete file references, no filler.
- The executor only appends, under the item it is answering:
  `**Response (round N):** ...` - what changed, or why no change is needed.
- Only the reviewer flips `[ ]` to `[x]`. It may append its own note when
  closing or rebutting.
- The raw stdout of each reviewer/executor invocation is captured to a log
  file outside the repo (orchestrator picks a temp path and reports it).
  The review file stays the only channel of record.

## The loop (plan-review)

1. **REVIEW**: orchestrator spawns the reviewer with the `review-initial`
   template. Reviewer writes the review file.
2. **PAUSE**: orchestrator summarizes the review to the human and waits.
3. **ADDRESS**: executor fixes and responds to every open item.
4. **VERIFY**: orchestrator resumes the same reviewer session with the
   `review-verify` template. Reviewer closes what is adequately addressed,
   may add new items for problems the fixes introduced.
5. Back to 2. An item still open after 3 verify rounds is a genuine
   disagreement: stop, tag it `[escalated]`, and hand it to the human.
6. When every item is closed, run `plan-conformance-pass` for the work
   item as the terminal gate.

The reviewer session is resumed (not fresh) across rounds of one work
item, so it remembers its own review. A new work item gets a new session.

### Panels

More than one reviewer may fill the reviewer seat. Each panel member is
its own session (own thread id, resumed for its own verify rounds) and
gets the panel variants of the templates (ROLES.md, "Panel addendum"),
which scope it to a `## {REVIEWER_NAME}` section of the review file: it
writes and closes items only there. The orchestrator serializes reviewer
invocations - never two writers against the review file at once - and the
executor addresses open items in every section. The round cap applies per
item, as usual.

## The audit (plan-conformance-pass)

One reviewer invocation with the `conformance` template, fresh session.
Scope is either a single work item (terminal gate of the loop) or the
entire plan (a standalone drift audit across everything delivered).
It answers a different question than the loop: not "were my comments
addressed" but "is what was delivered what the plan called for". Output is
a conformance file in the same checklist format; findings worth acting on
feed back into a `plan-review` round.

## Profiles

A profile is a CLI recipe for filling a seat. All verified on
codex-cli 0.153.4 and claude code. Run from the repo root.

### codex (default reviewer)

- New session:
  `codex exec --sandbox workspace-write --json "<prompt>"`
- Resume: flags go BEFORE the subcommand:
  `codex exec --sandbox workspace-write --json resume <thread-id> "<prompt>"`
- Thread id: first stdout line,
  `{"type":"thread.started","thread_id":"..."}`.
- Model override: append `-m <model>`; reasoning effort:
  `-c model_reasoning_effort="high"`. Name these variants
  `codex:<model>` / `codex:<model>:high` when reporting to the human.
- Sandbox: `workspace-write` is the grant (full read + exec, writes
  confined to the repo tree); the role prompt confines writes further to
  the review file. Reviewer seats never need more; never pass
  `--dangerously-bypass-approvals-and-sandbox`.

### claude

- New session:
  `claude -p --permission-mode acceptEdits --output-format json "<prompt>"`
- Session id: `session_id` field of the JSON result.
- Resume: `claude -p --resume <session-id> --permission-mode acceptEdits --output-format json "<prompt>"`
- Model override: `--model <model>` (profile name `claude:<model>`).

Adding a profile for another agent CLI means adding a section here: a new
command, a resume command, and where its session id lives. The protocol
does not change.

## Status

Claude-executes / codex-reviews is the exercised path. The flipped seats
(codex executes via its adapter, claude reviews) and multi-reviewer
panels (see "Panels" and the panel addendum in ROLES.md) are wired but
not yet exercised; expect rough edges the first time and fix them here.
