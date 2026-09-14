# Spawned executor

> **Status:** approved 2026-09-13

## Intent

The orchestrator session should be lean and work purely as an
orchestrator. Today it doubles as executor by default: when the human
asks for the next work item, the implementation happens inside the
orchestrator's own session, bloating its context with implementation
detail and blurring the seat boundaries. Instead, the orchestrator
spawns the executor as its own fresh session, gives it only what the
plan documents provide, monitors the outcome through files, and carries
on with the review loop. The human keeps talking to one lean session
that coordinates everything and implements nothing.

## Decisions

All from the 2026-09-13 interview; final.

| # | Decision |
|---|----------|
| 1 | Spawned executor is the ONLY mode. The orchestrator never implements; even trivial items go through a spawned executor. Every item thereby tests whether the plan docs alone are sufficient context. |
| 2 | The executor is a fresh CLI process per the PROTOCOL.md profiles (`claude -p` / `codex exec`), exactly like the reviewer seats. |
| 3 | Executor grant, named honestly: full write+exec (`--permission-mode bypassPermissions` for claude, `--sandbox workspace-write` for codex). The audit trail is the diff plus the worklog; nothing is committed without the human. |
| 4 | Executor and implementation-reviewer profiles are recorded in plan.md's Decisions table at plan-create time (the create adapters ask for them during the interview; the design-review reviewer stays a per-invocation choice as today). Any implementation invocation may override per run; an override that changes the executor LLM mid-item cannot resume the old CLI's session, so it forces a fresh spawn and is recorded as a worklog `[decision]`. Plans without recorded profiles (all pre-existing ones) fall back to the defaults - executor `claude`, reviewer `codex` - stated by the orchestrator at spawn time. |
| 5 | For the implementation loops (plan-implement, plan-item-review), the hard rule is: executor-LLM != reviewer-LLM, checked at spawn time; the orchestrator's model is irrelevant there because it executes nothing. The design review keeps its existing rule unchanged: the orchestrator edits the plan, so the reviewer must be a different LLM from the orchestrator. |
| 6 | Batch monitoring: the executor runs to completion or a `[blocker]`, writing worklog entries as it goes. The orchestrator judges artifacts afterwards - the diff and the worklog tail - and never tails live output. It classifies each exit per invocation: the `[session]` entry the orchestrator appends at every spawn AND every resume is the boundary, and only terminal entries the executor wrote after the latest boundary count. Exactly one of: **implemented** (`[implemented]` after the boundary), **blocked** (`[blocker]` after the boundary - goes to the human, never auto-resumed), or **abnormal** (no terminal entry after the boundary; the orchestrator appends a `[blocker]` on the executor's behalf recording the abnormal termination and goes to the human; a fresh spawn happens only on the human's go). Both after the boundary is a conflict, treated as blocked. Older entries are history and never classify a later invocation. |
| 7 | Pre-review gate: after an *implemented* exit the orchestrator runs the breakdown item's validation line. Red means resume the executor with the evidence, not spend a reviewer round: the orchestrator appends the failing command and trimmed output to the worklog, and the resume prompt points at that entry (the template stays the only channel). Three validation-red resumes on one item without going green is an escalation to the human, mirroring the review loop's round cap. Validation lines marked `human:` in the breakdown are for the human at the pause point and never trigger an executor round. |
| 8 | Human steering flows between rounds only, recorded as a worklog `[decision]`; the executor session is resumed pointing at it. No live channel, no mid-flight interrupts. An urgent stop is the human interrupting the orchestrator, which kills the executor's entire process tree (the CLI and any build/test children it spawned), confirms nothing from that tree survives before anything else may write to the tree, and records why as a `[decision]`. |
| 9 | ADDRESS resumes the same executor session across review rounds, parallel to the resumed reviewer; a fresh spawn only when the session is lost or the profile changed (decision 4). The association survives outside anyone's session memory: at every spawn the orchestrator appends a worklog `[session]` entry - item, seat, profile, session id - and a separately-invoked plan-item-review resumes from the item's latest `[session]` entry. A fresh session reconciles partial work from what the tree, review file, and worklog already show; the strict-context rule is what makes that sufficient. |
| 10 | Executor context is template-only, strict: work item, plan doc paths, review file, worklog pointer. Nothing from the orchestrator's session. A floundering executor is evidence of a plan-doc gap; the fix goes into the docs. |
| 11 | Scope: plan-implement and plan-item-review's ADDRESS step. plan-create's design review keeps the orchestrator as plan editor - it is mid-interview with the human and the edits are the conversation. |
| 12 | This change itself is built through the plan-* lifecycle (this plan), after phase 4 of the dotfiles migration closed (it did, 2026-09-13). |

## Scope

**In**

- `home/.config/plan-skills/PROTOCOL.md`: the Seats section (executor
  becomes a spawned seat; orchestrator described as never implementing),
  the hard rules (decision 5), the loop (spawn, batch-monitor, validate,
  resume semantics), the Profiles section (executor grants beside the
  reviewer grants), and the Status section (what is now exercised).
- `home/.config/plan-skills/ROLES.md`: the executor template becomes the
  spawned executor's full prompt - implement the item from the plan
  docs, append worklog entries (`[implemented]`/`[blocker]`), stop at
  any wall, never close review items, never commit. Resume wording for
  validation-red and ADDRESS rounds.
- `home/.config/plan-skills/ARTIFACTS.md`: two worklog types join the
  contract - `[implemented]` (the executor finished an item pre-review:
  what changed, how verified locally; `[done]` keeps its committed
  meaning) and `[session]` (seat spawn record: item, seat, profile,
  session id).
- `plan-create` adapters (both CLIs), narrowly: the interview also asks
  for and records the executor and implementation-reviewer profiles
  (decision 4). The design review loop itself is untouched.
- Adapters, all four: `plan-implement` and `plan-item-review` for both
  claude (`home/.claude/skills/`) and codex (`home/.codex/prompts/`),
  rewired so the orchestrator spawns/resumes the executor seat instead
  of doing the work, runs the validation gate, and reports from
  artifacts.
- One controlled end-to-end exercise of the new flow on a small real
  work item, and a Status-section record of what it proved.

**Out**

- plan-create's design review loop (decision 11).
- plan-sync, plan-conformance-pass, plan-archive: no seat changes.
- Live monitoring, checkpointed execution, any executor-to-orchestrator
  channel beyond the files.
- New profiles or CLIs; panels for the executor seat (one executor per
  item).

**Stretch**

- None. Keep the change minimal and exercised.

## Risks

- **Executor under-context.** Severity: medium. Template-only context
  will fail on plans whose docs are thin. Mitigation: that failure is
  the design working (decision 10) - the loop is: improve the docs,
  resume. The exercise item (breakdown) deliberately probes this.
- **Headless permission surprises.** Severity: medium. `claude -p
  --permission-mode bypassPermissions` and sandboxed `codex exec` may
  still hit walls (network, paths outside the tree). Mitigation: the
  executor template's any-wall `[blocker]` rule plus the exercise item;
  findings land in PROTOCOL.md's profile notes.
- **Session loss between rounds.** Severity: low. A lost executor
  session degrades to a fresh spawn (decision 9), which the strict
  context rule makes survivable by construction.
- **Protocol/adapters skew.** Severity: low. Adapters instruct
  orchestrators to read PROTOCOL.md at runtime, so protocol and adapter
  text must land together, atomically (breakdown orders this).
- **Self-hosted transition.** Severity: medium. Item 1 rewrites the
  rules it is being executed under, and this machine live-links
  `~/.config/plan-skills` into the checkout (devCheckout), so edits are
  visible to any running session mid-item; store-managed consumers see
  nothing until a rebuild. Mitigation: item 1 is explicitly the last
  orchestrator-executed item, run and reviewed under the old protocol
  in a single session that does not re-read the core mid-loop; item 2
  starts by verifying `~/.config/plan-skills` resolves to the updated
  content before any seat is spawned.

## Success criteria

- A plan-implement invocation implements a real item with the
  orchestrator authoring none of it: every change to the work item's
  files is made by the executor process, and the orchestrator's own
  writes are limited to filled role prompts, `[session]`/`[decision]`/
  validation-evidence worklog entries, and reports to the human.
  Reading the diff and worklog to judge and report is expected, not a
  violation - the boundary is authorship, witnessed by the human from
  the orchestrator transcript.
- The executor's work survives the existing review loop unchanged:
  reviewer templates, pause points, sole-closer rule all untouched, and
  the design review's orchestrator-as-editor exception explicitly
  preserved.
- The exit taxonomy is real: the exercise produces evidence of the
  implemented, validation-red, and blocked-or-abnormal paths (forced
  where they do not occur naturally), and at least one resume of the
  executor session (ADDRESS or validation-red - same mechanics).
- The validation gate demonstrably catches a red state before a
  reviewer round at least once (forced in the exercise if it does not
  occur naturally).
- PROTOCOL.md's Status section records the spawned path as exercised,
  with rough edges fixed or filed.

## Open questions

- ~~Which small real work item the end-to-end exercise uses~~ Answered
  at implement time: the tmux install (docs/plans/tmux-tui-smoke),
  plus the herdr runtime cleanup (docs/plans/herdr-runtime-cleanup) as
  the under-context micro-probe.
- ~~Whether `claude -p` needs an explicit tool allowlist beside
  `bypassPermissions` for long-running builds~~ Answered empirically:
  no allowlist needed inside the executor - it ran nix builds and the
  full test suite headless. The permission friction is on the
  orchestrator side (spawning `claude -p` needs a Bash allow rule and
  stdin prompt delivery); see PROTOCOL.md's Status rough edges.
