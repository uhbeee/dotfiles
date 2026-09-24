# plan-skills protocol

A review loop between AI agents that never talk to each other directly.
All communication goes through markdown files the human can audit at
any point: the review file carries review items and responses, the
worklog carries executor outcomes, session records, validation
evidence, and human steering. The plan documents, not anyone's session
memory, are the source of truth for what the work should be.

The plan-* family shares this protocol: `plan-create` (interview, draft,
design review, human sign-off), `plan-implement` (the next work item),
`plan-item-review` (the review loop for one implemented item),
`plan-sync` (reconcile the plan docs after an item lands) and
`plan-conformance-pass` (the whole-delivery audit). Role prompt templates
live in ROLES.md next to this file; the documents the family maintains -
the plan directory, worklog, approval gate, review-surface publish
checkpoints - are defined in ARTIFACTS.md.

## Seats

- **Orchestrator**: the agent the human is talking to. Drives the
  loops, spawns the other seats as fresh CLI processes (profiles
  below), and pauses for the human at the marked points. In the
  implementation loops it implements nothing: its own writes are
  filled role prompts, worklog `[session]`/`[decision]`/
  validation-evidence entries, and reports to the human - it reads the
  diff and worklog to judge and report, but authors no part of the
  work. The one exception is plan-create's design review, where the
  orchestrator edits the plan documents itself.
- **Executor**: a spawned seat that does the work (see "The executor
  seat"). Implements items from the plan documents alone, addresses
  review items by fixing the work then appending a response under each
  item. Never marks an item closed, never commits.
- **Reviewer**: judges the work against the plan docs. Writes the review
  checklist, verifies fixes, and is the only seat that closes items.

Hard rules, regardless of who fills which seat:

- In the implementation loops (plan-implement, plan-item-review):
  executor-LLM != reviewer-LLM, checked at spawn time; the
  orchestrator's own model is irrelevant there because it executes
  nothing. In the design review the orchestrator edits the plan, so
  the reviewer must be a different LLM from the orchestrator - that
  rule is unchanged. A profile selection that would break either rule
  stops for the human.
- Executor and implementation-reviewer profiles are recorded in
  plan.md's Decisions table at plan-create time; any invocation may
  override per run. A mid-item override that changes the executor LLM
  cannot resume the old CLI's session: it forces a fresh spawn,
  recorded as a worklog `[decision]`. Plans without recorded profiles
  fall back to the defaults - executor `claude`, reviewer `codex` -
  stated by the orchestrator at spawn time.
- A spawned seat receives ONLY its role prompt with the placeholders
  filled: for the reviewer, the plan doc paths and review file; for the
  executor, the work item, plan doc paths, review file, and worklog.
  Never anyone's session context, summaries, or chat. The executor's
  case lives in the review file responses or nowhere; a floundering
  executor is evidence of a plan-doc gap, and the fix goes into the
  plan documents, not the prompt.
- No seat communicates with another except through the review file and
  the worklog.
- The human gates everything at the pause points and owns landing the
  work: no agent commits, pushes or opens a pull request on its own
  initiative, and nothing reaches the default branch except through a
  pull request - never a direct push. Each of those steps takes the
  human's explicit go, and a go for one is not a go for the next. On
  that go the orchestrator may commit, push the work branch and open
  the PR for them - and opening it is where the agent stops: the PR is
  left for the human to review. Merging takes its own instruction, given
  after they have seen that PR and naming it. A go to push or open, or
  any earlier or broader word about landing the work, never carries
  merge authorization with it; when in doubt the PR stays open. Spawned
  seats are stricter still and never commit or push at all (ROLES.md).

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
  The review file stays the channel of record for review items and
  responses; the worklog is the channel of record for everything else
  (outcomes, sessions, evidence, steering).

## The executor seat (plan-implement)

The orchestrator spawns the executor as a fresh CLI process with the
`executor` template, then judges the outcome from files only - the
diff and the worklog tail - never by tailing live output.

- **Session record**: `[session]` entries come in pairs, for every
  spawned seat - executor, reviewer, conformance, each panel member -
  not just the executor. Immediately before every spawn AND every
  resume, the orchestrator appends the boundary entry - item, seat,
  profile, invocation number - which is the classification boundary
  below. When the CLI reports the session id, the orchestrator appends
  the id entry - seat, invocation number, session id - which is the
  resume pointer. Codex prints its thread id on the first stdout line,
  so that entry can land while the seat still runs; `claude -p` reports
  it only in the JSON result at exit, so for a claude seat the id entry
  normally lands *after* the seat's own terminal entry. That is the
  honest record, not a defect - the id is written as soon as it is
  known, and the entry may say when it was observed. What the record
  must never do is falsify chronology: no id back-dated to look as if
  it had been seen earlier, and none reconstructed from anywhere but
  the CLI's own report. An id that was never reported is simply absent
  - a boundary with no id entry has no resumable session, and recovery
  is a fresh spawn, which is also what a crash before the id leaves
  behind.
  Resume pointers are per seat, now that every seat has records: an
  executor resume (ADDRESS, validation, steering, including a
  separately-invoked plan-item-review) takes the item's latest id entry
  *whose seat is executor*; a verify round takes that reviewer's own
  latest id entry, and each panel member resumes from its own. Reading
  "the item's latest id entry" without filtering by seat will resume
  the wrong seat, on the wrong CLI - which is why the id entry names
  the seat.
  The orchestrator also names itself: at the first boundary of a run it
  records its own seat and profile, so who orchestrated is read from
  the worklog rather than guessed from the surrounding prose.
- **Exit classification**, per invocation, from terminal entries the
  executor wrote after the latest `[session]` boundary - older entries
  are history and never classify a later invocation:
  - **implemented**: an `[implemented]` entry after the boundary; run
    the validation gate.
  - **blocked**: a `[blocker]` entry after the boundary; goes to the
    human, never auto-resumed. Both kinds after the boundary is a
    conflict, treated as blocked.
  - **abnormal**: no terminal entry after the boundary; the
    orchestrator appends a `[blocker]` on the executor's behalf
    recording the abnormal termination and goes to the human. A fresh
    spawn happens only on the human's go.
- **Validation gate**: after an implemented exit, run the breakdown
  item's validation line. Red: append the failing command and trimmed
  output to the worklog, then resume the executor with the
  `executor-resume-validation` template pointing at that entry - the
  template stays the only channel. Three validation-red resumes on one
  item without green is an escalation to the human. Validation lines
  marked `human:` are for the human at the pause point and never
  trigger an executor round.
- **Steering**: human input flows between rounds only, recorded as a
  worklog `[decision]`; the executor session is resumed with the
  `executor-resume-steering` template pointing at it - the template
  for continuing after a `[decision]` resolves a blocker or redirects
  the work, including the doc-gap path (blocker, docs repaired,
  resume). An urgent
  stop is the human interrupting the orchestrator, which kills the
  executor's entire process tree (the CLI and any build or test
  children it spawned), confirms nothing from that tree survives
  before anything else may write to the tree, and records why as a
  `[decision]`.
- **Resume vs fresh**: validation-red and ADDRESS rounds resume the
  same executor session. A fresh spawn happens only when the session
  is lost or the executor profile changed, and it uses the full
  `executor` template, whose opening reconciliation rule makes it
  pick up partial work from what the tree, review file, and worklog
  already show - the strict-context rule is what makes that
  sufficient.
- **Every invocation terminates in the worklog**: fresh spawns and
  resumes alike end with a terminal entry (`[implemented]` or
  `[blocker]`) after their boundary, so classification works the same
  in every round - including ADDRESS.

## The loop (plan-item-review)

1. **REVIEW**: orchestrator spawns the reviewer with the `review-initial`
   template, recording the `[session]` pair as for any seat ("The
   executor seat", Session record). Reviewer writes the review file.
2. **PAUSE**: orchestrator summarizes the review to the human and waits.
3. **ADDRESS**: orchestrator resumes the executor session (the item's
   latest `[session]` id entry *for the executor seat* - the reviewer's
   id entries sit in the same worklog) with the `executor-address`
   template;
   the executor fixes and responds to every open item.
4. **GATE**: before any reviewer round is spent, the orchestrator
   classifies the ADDRESS invocation's exit per "The executor seat"
   (blocked and abnormal go to the human) and re-runs the item's
   validation line - after every implemented exit, unconditionally;
   red follows the validation gate (evidence, resume, cap), not the
   review loop. Only an implemented exit with green validation
   proceeds.
5. **VERIFY**: orchestrator resumes the same reviewer session - that
   reviewer's own latest id entry, each panel member from its own -
   with the `review-verify` template. Reviewer closes what is
   adequately addressed, may add new items for problems the fixes
   introduced.
6. Back to 2. An item still open after 3 verify rounds is a genuine
   disagreement: stop, tag it `[escalated]`, and hand it to the human.
7. When every item is closed, run `plan-conformance-pass` for the work
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

## The design review (inside plan-create)

The same loop, run over the plan itself before any implementation: the
reviewer plays principal engineer on a design document. Because the
orchestrator edits the plan here, the reviewer must be a different LLM
from the orchestrator, whichever LLM orchestrates: a claude
orchestrator takes a non-claude reviewer (default codex), a codex
orchestrator a non-codex reviewer (default claude). Differences from
the item loop: the templates are `design-review` / `design-review-verify`;
the review file is `plan_review.md` in the plan directory; and the source
of truth is the Intent and Decisions sections of the plan under review,
since no other document outranks it yet. The orchestrator is the executor
and addresses items by editing the plan documents - the one place it
still edits anything, so the executor seat's machinery does not apply
here: no spawned seat, no `[session]` entries, no exit classification,
and no GATE step (step 4), since there is no ADDRESS invocation to
classify and the draft breakdown's validation lines describe work not
yet implemented; the loop proceeds from plan edits straight to VERIFY.
The loop's other rules (pause points, resumed reviewer session, round
cap, sole-closer) apply unchanged, with one more exception: there is no
conformance gate, because nothing has been delivered yet - step 7 of
the item loop does not apply.
When the design checklist closes, what follows is the human's own review
and sign-off (ARTIFACTS.md, "Approval gate"); the loop informs the
sign-off, never replaces it.

## The audit (plan-conformance-pass)

One reviewer invocation with the `conformance` template, fresh session.
Scope is either a single work item (terminal gate of the loop) or the
entire plan (a standalone drift audit across everything delivered).
It answers a different question than the loop: not "were my comments
addressed" but "is what was delivered what the plan called for". Output is
a conformance file in the same checklist format; findings worth acting on
feed back into a `plan-item-review` round.

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
- Executor seat: the same commands and grant - `workspace-write` is
  already full write + exec within the tree, which is what an executor
  needs, with one real gap: nix builds fail inside it for an executor
  seat exactly as they do for a reviewer (the fetcher's lock is denied),
  so a codex executor cannot run a validation line that builds. See
  "When the executor's sandbox cannot validate" below before working
  around it.
- Interactive asks from the orchestrator seat: codex's native picker is
  `request_user_input`, gated behind the under-development feature flag
  `default_mode_request_user_input` - without it the tool is absent from
  the tool list and codex asks in numbered prose instead. Enable it per
  machine in `~/.codex/config.toml` under `[features]` (that file mixes
  in machine-local trust entries, so it is not repo-managed). Codex's
  collaboration modes then govern how it may be used, and a skill does
  not override them. In Plan mode the picker is the preferred route for
  any question and codex biases toward asking over guessing, but nothing
  may write files. In Default mode - where anything that writes runs -
  the picker is for optional questions only, an empty return means
  continue on best judgment rather than re-ask, and required input is
  one concise plain-text question instead, never choices typed into a
  message; permission asks never go through the tool at all. Every call
  carries one to three questions (prefer one) and each question needs
  options. Only the human switches modes (Shift+Tab). So plan-create's
  interview wants Plan mode and its drafting half Default, with the
  handoff asked for and waited on; the other skills run in Default and
  keep their mandatory asks in plain text. Spawned seats need none of
  this: `codex exec` refuses the tool, and a seat gets its whole
  template as an argument.
- Seats get their filled template as the inline `<prompt>` argument, so
  spawning never depends on codex discovering anything on disk. Entry
  points are the other half: the human-facing `plan-*` adapters are
  codex skills (`~/.codex/skills/plan-<name>/SKILL.md`, mentioned as
  `$plan-<name>`), since 0.153.4 has no custom-prompt discovery at all.

### claude

- New session (reviewer seats):
  `claude -p --permission-mode acceptEdits --output-format json "<prompt>"`
- Session id: `session_id` field of the JSON result.
- Resume: `claude -p --resume <session-id> --permission-mode acceptEdits --output-format json "<prompt>"`
- Model override: `--model <model>` (profile name `claude:<model>`).
- Executor seat: `--permission-mode bypassPermissions` in place of
  `acceptEdits`, new session and resume alike. Named honestly: the
  executor edits files and runs builds and tests headless, where
  permission prompts cannot be answered; the audit trail is the diff
  plus the worklog, and nothing is committed without the human.
  Reviewer seats keep `acceptEdits`.

Adding a profile for another agent CLI means adding a section here: a new
command, a resume command, and where its session id lives. The protocol
does not change.

### When the executor's sandbox cannot validate

A seat whose sandbox cannot run a command the item requires (today: a
codex executor on anything that builds with nix, or any command needing
privilege) does not get a wider grant, and does not guess the result.
The handoff runs on the existing rails, in this order:

1. **The executor blocks.** A command it cannot run is a wall like any
   other: it appends a `[blocker]` naming the exact command lines it
   needs run and what it will do with each outcome, and stops. It never
   skips the check, and never reports work as verified on the strength
   of a command it could not run.
2. **The human decides.** That blocked exit goes to the human like
   every other one - no auto-resume - and their authorization to run
   the commands is a `[decision]`. This is what makes the handoff
   deliberate rather than an orchestrator improvising around a wall.
3. **The orchestrator runs exactly those commands**, nothing adjacent,
   and appends a `[validation]` entry with the command, exit code and
   enough output for someone else to act on it - whether it passed or
   failed.
4. **The executor is resumed with `executor-resume-steering`**, the
   template for continuing after a `[decision]` resolves a blocker,
   pointing at that entry. Not `executor-resume-validation`, which is
   for an `[implemented]` exit that then failed its gate - a different
   situation. The entry is the result: the executor works from what it
   records and does not re-run the impossible command. If the fix needs
   another privileged run, that is another `[blocker]`, and the cycle
   repeats through the human.

Later gate runs of the same line stay with the orchestrator for the
same reason, recorded the same way.

The boundary is narrow and worth stating twice: the orchestrator runs
commands and records results. Reading the failure, diagnosing the
cause, writing the test or the fix, touching the repository - all the
executor's. An orchestrator that diagnoses or repairs has stopped
orchestrating, so any split wider than this needs the human's go, a
`[decision]` recording it, and a rough-edge note here; it is never a
precedent. The cleaner escape is an executor profile whose sandbox can
run the line - a claude executor has no such limit - which is a
profile choice at spawn time, not a grant to widen.

## Status

Claude-executes / codex-reviews is the exercised pairing, including the
spawned executor seat: exercised end to end on two real work items
(the tmux-tui-smoke plan and the herdr-runtime-cleanup micro-plan,
both 2026-09-13, as the spawned-executor plan's item 2). Witnessed
across those runs: implemented exits; a validation-red caught by the
gate before any reviewer round, with evidence handoff and a
same-session resume to green (tmux); a blocked exit escalated to the
human at a privilege wall, repaired by rescoping the validation line
via `[decision]` plus a steering resume (tmux); the under-context path
proper - the docs withheld a fact only the human could supply (the
confirmed-stale file list), the executor walled with a `[blocker]`
naming it and changed nothing, the human supplied it as a
`[decision]`, and a steering resume of the same session implemented
it (herdr); review loops and item conformance closed clean on both;
and an orchestrator that authored none of either item's changes.

A codex orchestrator has since been exercised too: codex orchestrating,
codex executing, claude reviewing, one plan end to end (bump-lavish-axi,
2026-09-23, now archived), audited afterwards against its own trail.
What that run does establish: the review loop and item conformance
closed on their merits, ~16 orchestrator-run `[validation]` entries
carry commands, exit codes and store paths, a validation-red was caught
by the gate and recovered to green through a resume, seven executor
invocations ended in terminal entries, and nothing was closed without
the work behind it.

What it does not establish, stated here so the summary is not read for
more than it is worth:

- The executor was codex under a codex orchestrator. The
  claude-executor-under-codex-orchestrator pairing - the one some plans
  name specifically - remains unexercised.
- Recording was not compliant. Executor invocations got proper
  boundary/id pairs, but reviewer seats did not: the initial
  implementation reviewer and the conformance reviewer each got a
  single combined `[session]` entry (profile and id together, no
  boundary before the spawn), and the verify rounds' reviewer sessions
  were named only inside `[handoff]` prose. One executor id entry was
  also written after its own terminal entry as a reconstruction rather
  than a report. Seven eventual executor pairs are not the same as a
  clean record; the session-record rules above were tightened because
  of this run, not confirmed by it.
- Seat discipline held in the main, but not everywhere: at the runtime
  failure the orchestrator wrote the root-cause diagnosis itself, which
  "When the executor's sandbox cannot validate" now reserves to the
  executor. That subsection exists because this run improvised the
  split; the run is the evidence of the problem, not of the fix.
- That plan's opening decision waived review-surface publishes for its
  implementation phase, so the publish-at-each-pause lifecycle was not
  exercised by it either.

Not yet witnessed: an abnormal exit (the classification path is
untested live). Multi-reviewer panels (see "Panels" and the panel
addendum in ROLES.md) remain wired but unexercised; expect rough edges
the first time and fix them here.

Rough edges from the exercise, filed:

- Spawning `claude -p` from an orchestrator harness with permission
  prompts: the auto-mode classifier blocked the executor spawn until a
  `Bash(claude -p*)` allow rule was added, and the prompt had to be
  delivered via stdin - `$(cat ...)` command substitution stayed
  blocked. So `bypassPermissions` on the executor is not the whole
  story; the orchestrator side needs the allow rule and stdin delivery.
- The codex `workspace-write` sandbox cannot run nix builds (store
  cache writes are denied, and the fetcher's lock with them), so codex
  reviewer and conformance seats cannot reproduce build-dependent
  validation lines; they judge from the orchestrator's gate evidence in
  the worklog instead. The bump-lavish-axi run showed this bites a
  codex *executor* just as hard: its validation line could not run at
  all, and the human approved a split where the orchestrator ran the
  builds and runtime checks. That kept the letter of "the orchestrator
  implements nothing" while the diagnosis drifted to the orchestrator
  too - which is why the split is now bounded in "When the executor's
  sandbox cannot validate" rather than left to judgment.
- ARTIFACTS.md defined no worklog type for the validation gate's
  evidence, so ad-hoc `[validation]` entries were used across several
  plans (~16 in bump-lavish-axi alone) before the type existed. Closed:
  `[validation]` is now a defined type in ARTIFACTS.md.
- A `bypassPermissions` executor can out-engineer an intended
  under-context wall: given docs that omitted the needed rebuild, it
  built the target system itself with `--override-input` instead of
  stalling, and the wall arrived one round late at the sudo boundary.
  What the tmux run therefore tested is the permission wall (blocked
  exit at missing privilege), not under-context; a derivable fact is
  no probe for an executor with full exec. The under-context evidence
  came from the herdr run, whose withheld fact was a human judgment
  (which files are stale) that no amount of privilege could derive.
- `claude -p` reports its session id only at exit, so the `[session]`
  id entry always lands post-invocation - as the session-record note
  above states; observed, not just predicted.
- codex-cli 0.153.4 ignores `~/.codex/prompts` entirely: custom prompts
  are gone, so the `/plan-*` entry points the codex adapters were
  authored as never resolved on it (measured against the installed CLI:
  regular file, symlinked file, dash-free name and frontmatter variants
  all produce an empty slash popup while built-ins match). The adapters
  are codex *skills* now - same SKILL.md shape as the claude side,
  invoked `$plan-<name>`. Discovery has a shape rule worth knowing
  before wiring them from a config manager: a skill directory that is
  itself a symlink is discovered, a real directory holding a per-file
  `SKILL.md` symlink is not.
- The orchestrator wrote `[done]` for the tmux item's review-loop and
  conformance completions while the commit was still pending, against
  ARTIFACTS.md's committed-only meaning; both entries are superseded
  by an append-only `[decision]` in that worklog. Pre-commit
  milestones take `[handoff]` (or the entry type of the event itself);
  `[done]` is reserved for landed work.
