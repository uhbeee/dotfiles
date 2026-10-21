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

**The protocol holds the behavior; the adapters stay thin.** Each agent
CLI reaches this family through its own adapter - a `plan-<name>`
skill per member (`~/.claude/skills/plan-<name>/SKILL.md`,
`~/.codex/skills/plan-<name>/SKILL.md`) - and an adapter's whole job is
to name the arguments it needs, point its orchestrator at these three
files, and restate the gates it must not skip. Nothing is reachable
from one orchestrator and not another: a step, gate, or lifecycle that
exists in one adapter and not its counterpart is a defect in the one
that lacks it, whichever way round, and a change to the flow changes
every adapter or none. What legitimately differs between adapters is
CLI-specific how, not what - codex's collaboration-mode rules for
asking, claude's question tool, each CLI's own default reviewer where
the different-LLM rule forces one - and a difference of that kind says
so in the adapter. Behavior that would otherwise live in every adapter
belongs here instead, which is what keeps them thin enough to stay in
step. Adding a third CLI is a new adapter over this same protocol, not
a second description of the flow.

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
- **Where the seat runs**: headless, the seat's cwd is the repo root
  the orchestrator was invoked from. Inside herdr, a plan's seats are
  hosted in that plan's worktree workspace and share its checkout
  across every item and every invocation, located each time by the
  work branch and recovered rather than recreated; the orchestrator's
  own validation and diff inspection move into that checkout too,
  while the plan documents stay in the primary checkout. The full
  lifecycle - creation, the recovery arms, status tokens, the teardown
  gate - is "The plan workspace" under Profiles.

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
codex-cli 0.153.4 and claude code. Run from the repo root. The codex
and claude recipes below are the headless forms; inside herdr the
herdr-hosted variants further below are selected automatically, and
everywhere else the headless forms apply unchanged.

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

### herdr-hosted variants

Inside herdr the same seats run as interactive herdr agents in their
own panes instead of headless processes. Selection is automatic: when
`test "${HERDR_ENV:-}" = 1` passes and the caller context vars are
present (`$HERDR_WORKSPACE_ID`, `$HERDR_PANE_ID`), seats are spawned
per this section; when the check fails (SSH, other machines, plain
terminals) the headless recipes above apply unchanged. Verified on
herdr 0.9.0; check `herdr status` before relying on anything newer.
Everything above the profile layer is untouched: same role templates
(ROLES.md unchanged), same review-file and worklog rules, same gates.
The temp-log stdout capture does not apply here - the pane transcript
is the live record and `herdr agent read <name>` inspects it, so no
log path is reported. Reading is state-dependent: `--source
recent-unwrapped --lines <N>` works on a settled-idle seat, but a
seat that is working, blocked, or unknown rejects any read whose
`--lines` needs alternate-screen history (`agent_not_idle` - that
history can only be captured by scrolling while idle); read non-idle
seats with `--source visible`.

**Naming and panes.** A seat's agent name is unique per item and
seat among live agents and must match `[a-z][a-z0-9_-]{0,31}`:
`exec-<item-slug>` and `review-<item-slug>` (panel members
`review-<reviewer>-<item-slug>`), slug truncated to fit. Names free
on agent exit, so a replacement spawn reuses its predecessor's name
once the old pane is gone. Each seat gets its own pane, split from
the orchestrator's as a sibling - or, when the plan has a worktree
workspace, from that workspace's pane instead ("The plan workspace"
below):

```bash
herdr pane split --pane "$HERDR_PANE_ID" --direction right \
  --cwd <seat working tree> --no-focus
```

Direction follows the orchestrator pane's geometry (wide splits
right, tall splits down; `herdr pane layout` tells); the new pane id
is `.result.pane.pane_id`. Teardown is the orchestrator's: it closes
only panes it split (`herdr pane close <pane-id>`), and only when the
seat is finished for good - the item's review loop and conformance
gate closed, the seat replaced by a fresh spawn (dead pane closed
first), or the urgent stop (below). A pane whose seat settled with a
`[blocker]` stays open, carrying its mark (below), until the human's
steering resume.

**Start.** `herdr agent start <name> --kind <kind> --pane <pane-id>
-- <native flags>`. The flags after `--` carry the same grants as the
headless recipes, minus the headless plumbing (no `-p`, no `exec`, no
`--json`/`--output-format` - ids and state come from herdr):

- claude executor: `-- --permission-mode bypassPermissions`
- claude reviewer: `-- --permission-mode acceptEdits`
- codex, either seat: `-- --sandbox workspace-write -c
  'sandbox_workspace_write.writable_roots=["<abs plan docs dir>"]'` -
  `workspace-write` confines writes to the seat's tree, and the
  writable root re-admits the plan directory (review file, worklog)
  when it lives outside that tree. Model overrides ride the same
  flags (`-m <model>`, `-c model_reasoning_effort="high"`).

`agent start` returns once the agent is detected and ready for
input. If it returns `agent_not_ready` (blocked during startup), the
name still resolves for `agent read` (`--source visible` - the seat
is not idle) and `agent send-keys`: inspect and surface it like any
live input wait below - never answer it yourself.

**Prompt via file.** The orchestrator writes the filled role template
to a file under the plan directory
(`<plan docs dir>/prompts/<seat name>-inv<N>.md`), so every prompt is
auditable on disk, then submits a one-liner:

```bash
herdr agent prompt <name> \
  "Read and follow your role prompt at <absolute path>." --wait
```

The prompt text stays a one-liner pointing at the file: `--wait`
requires observed activity within ~5s of submission, and a fat
payload risks `agent_prompt_stalled`. On `agent_prompt_stalled` or
`timeout`, inspect (`agent get`, `agent read`) before deciding
anything - neither proves the prompt was never delivered; do not
blindly resubmit. `agent prompt` rejects a seat already parked at a
dialog with `agent_blocked` before sending any input: that seat is in
a live input wait, not promptable.

**Wait.** There is no process exit; the invocation ends when the
agent settles. `--wait` (or a standalone `herdr agent wait <name>`)
returns on the first settled `idle`, `done`, or `blocked`. Omit
`--timeout` on seat invocations: after observed activity the
settled-state wait is indefinite, which is what a long executor run
needs. Interrupting the orchestrator only abandons its wait - the
seat runs on in its pane - so an urgent stop follows its own rule
below.

**Urgent stop.** The human interrupting the orchestrator no longer
kills the seat: the hosted executor keeps running with whatever build
or test children it spawned. The hosted urgent stop quiesces the
tree before enumeration can be trusted - a list snapshotted while
processes can still fork is incomplete by construction - then kills,
then verifies, all by process identity (pids), never by matching
command lines:

1. Read the pane's shell pid from `herdr pane process-info --pane
   <pane-id>` (`.result.process_info.shell_pid`).
2. Quiesce: `kill -STOP` the shell pid, then loop - re-snapshot
   `ps -ax -o pid,ppid`, walk the parent links from the shell pid
   for descendants not yet listed, `kill -STOP` the newcomers -
   until a snapshot adds nothing. Stopped processes cannot fork, so
   the loop converges and the final list is the whole tree: a child
   forked mid-shutdown surfaces in a later snapshot and is stopped
   in turn. (`pgrep -P` is not a substitute for the walk - macOS
   pgrep silently omits the caller's own ancestors.)
3. `kill -KILL` every listed pid - SIGKILL takes stopped processes,
   where SIGTERM would sit pending until a SIGCONT that never
   comes - and verify each is gone (`kill -0 <pid>` fails). Nothing
   else may write to the tree until the whole list is dead. A pid
   that will not die, or a tree whose membership cannot be
   established (a child that already daemonized away from the
   ancestry walk), keeps the tree closed to writers and goes to the
   human as the uncertainty it is.
4. `herdr pane close <pane-id>` on the now-dead pane - the one
   exception to the teardown timing above; ownership is unchanged,
   the orchestrator is closing a pane it split. Closing is cleanup
   here, not the kill: it is never assumed to kill descendants.
   Herdr may have reaped the pane already when its shell died;
   `pane_not_found` then just means the cleanup is done.

Record why as a `[decision]` - the headless invariant unchanged. The
seat and its live session are gone; continuing is a fresh spawn on
the human's go.

**Blocked is two things**, kept apart at classification time:

- A settled herdr `blocked` is a live input wait: the seat is alive
  at an approval or question UI. It is never exit-classified. The
  orchestrator inspects (`herdr agent get <name>`, `herdr agent read
  <name> --source visible --lines 20` - visible, not
  recent-unwrapped: a blocked seat rejects alternate-screen-history
  reads with `agent_not_idle`) and surfaces it to the human; it
  never answers approval dialogs itself. A substantive
  answer is recorded as a worklog `[decision]` first, then the seat
  continues: the human attaches (`herdr agent attach <name>`) or the
  orchestrator relays the human's exact choice as keys (`herdr agent
  send-keys <name> <key> ...`), then waits again.
- A worklog `[blocker]` entry after the boundary with a settled
  (idle/done) executor keeps its existing meaning: the blocked exit,
  to the human, never auto-resumed.

**Exit classification** applies to executor invocations and is
unchanged in substance: when the executor settles idle or done,
classify from the terminal entries written after the latest
`[session]` boundary exactly per "The executor seat" - implemented,
blocked, abnormal (a settled executor with no terminal entry stays
abnormal). A reviewer invocation is never classified this way: it
writes no worklog entries, it is complete when it settles idle or
done, and its output is judged from the review file itself - the
initial round's checklist, a verify round's closures and notes - as
in the headless flow. Because an executor's `[blocker]` exit leaves
the native state reading idle/done, the orchestrator marks the pane
when it classifies the exit, so the parked blocker stays visible
while it awaits the human:

```bash
herdr pane report-metadata <pane-id> --source plan-skills \
  --display-agent "<seat name> [BLOCKED]" \
  --token blocked="<summary>"
```

and clears the mark on the steering resume:

```bash
herdr pane report-metadata <pane-id> --source plan-skills \
  --clear-display-agent --clear-token blocked
```

`--display-agent` is the half the human sees: on 0.9.0 the agents
panel renders the agent name, so overriding the name reaches the eye,
while `--token` and `--state-label` are stored and API-readable and
render nowhere (both were set on a real blocked seat and the panel
showed nothing - see Status). The token stays for machine readers;
the display agent is what makes a parked blocker visible, which is
what Decision 10 asks for. Metadata is stored per source, and the
panel shows whichever source wrote last, falling back to another
source's stored value when one is cleared - so this mark and the
subagent hook's own display summary share a pane without either
having to know about the other.

**Toasts.** When a seat invocation settles after running longer than
the threshold (default 60s), or settles blocked at any duration, the
orchestrator - the only party that knows a seat settled - raises:

```bash
herdr notification show "<seat name>: <settled state>" \
  --body "<item>: <one-line outcome>" --sound done \
  --position top-right
```

(`--sound request` when it settled blocked). `--position` is not
optional in practice: a toast is an overlay drawn in a corner of the
herdr TUI, not a macOS notification, and without the flag it lands in
whatever corner the build defaults to, where the human may not be
looking. Three accepted toasts reached nobody this way (Status).
`show` returning `shown: true` means the call was accepted, not that
anyone saw it.

**Session record.** The `[session]` boundary entry is unchanged. The
id entry records the herdr identities in place of a CLI-reported id:
agent name, workspace id, pane id, worktree path, and branch. Whether
a seat also gets its native session id depends on that agent's herdr
integration, and on when the integration has anything to report.
Read it live from `herdr agent get <name>`
(`.agent_session.value`) - no wait-for-exit - and read it again
later rather than once, because absent at spawn does not mean
absent. The claude and codex integrations are both
session-identity-only; seat state stays screen-detected regardless.

Three preconditions, each measured on 2026-10-21 and none implied by
the one before it:

1. The integration installed: `herdr integration status` reports it
   `current` (claude v9, codex v8 here). `herdr integration install
   codex` writes under `~/.codex`, so installing is the human's call.
   It does not retrofit sessions already running.
2. The agent trusting the hook. codex 0.163.0 parks a newly
   registered SessionStart hook behind its own trust review ("1 hook
   needs review before it can run", Installed 1 / Active 0), so the
   hook does not run and the id never arrives, however current the
   status reads. Trusting it is a human act in codex's own UI, and
   because the hook fires at session start, a seat whose session
   began before the trust never reports either.
3. The seat having taken a turn. A trusted, freshly spawned codex
   seat still reported `agent_session=None` at start and across four
   polls; one prompt later the same seat reported its thread id. A
   thread does not exist until there is a conversation to have an id
   for.

So for a hosted codex seat the id entry lands after the seat's first
prompt, not at `agent start` - an orchestrator that reads `agent get`
only at spawn time sees `None` and will record "no thread id
surfaced" wrongly. claude's hook reports at session start, so a
claude seat's id is there to read as soon as the seat is up. Once an
id exists, herdr's own session restore can resume that pane
(`codex resume <id>`). When it is genuinely absent, record none and
move on, and say which precondition was missing rather than calling
it a fact about herdr. Either way the id is identity for the
record: recovery stays fresh-spawn per the Resume rule, and scraping
`~/.codex/sessions` stays out.

**Resume.** While the seat's pane is alive, every resume - ADDRESS,
validation-red, steering - is another `herdr agent prompt <name> ...
--wait` to the same live agent, the resume template delivered the
same via-file way: the interactive session is its own continuity, no
resume flags. If the pane or agent is gone, recovery is a fresh spawn
with the full template for either kind: new pane, new `agent start`,
the reconciliation rule picking up the partial work from the tree,
review file, and worklog. The recorded claude session id identifies
the lost session in the record; it does not authorize resuming it.

### The plan workspace

Inside herdr a plan gets one worktree workspace on one work branch,
created at the plan's first work item and persisting as the plan's
home across items, human pauses, and orchestrator invocations. Hosted
seats run there; the orchestrator runs its validation and diff
inspection in that checkout. Plan documents stay in the primary
checkout - the checkout the plan directory lives in, where the human
works - and are written there by absolute path, codex seats via the
writable root above. Outside herdr none of this applies: the classic
single-checkout flow is unchanged and what the orchestrator offers at
an item is a plain branch.

**Branch naming: `work/<slug>`**, the plan directory's own slug. The
branch carries the work - library code, configuration, whatever the
items deliver - and never the plan documents, which live in the
primary checkout and are typically untracked; so a `plan/` prefix
would advertise the one thing the branch must not contain, and invites
exactly the misreading that the branch is where the plan lives. A plan
may override the convention in its own Decisions table, but the
default is this one, and it is stated here rather than per plan so
that any session on any machine consuming this protocol follows it.

**The branch is the only durable identity.** Workspace ids are not
stable across teardown or restarts, and a checkout path can resolve
through symlinks (`/tmp` vs `/private/tmp`), so neither is a lookup
key. Every lookup is one command against the primary checkout:

```bash
herdr worktree list --cwd <primary checkout>
```

matched on `.result.worktrees[] | select(.branch == "work/<slug>")`.

**The default branch** is needed twice - `--base` at creation, and the
containment half of the teardown gate - and both times it means the
primary checkout's *local* default branch, `refs/heads/<default
branch>`. Resolve it once:

```bash
remote=origin
name=$(git symbolic-ref --short "refs/remotes/$remote/HEAD")
name=${name#"$remote/"}
git rev-parse --verify "refs/heads/$name"
```

The remote HEAD supplies the name and nothing else. `git symbolic-ref
--short refs/remotes/origin/HEAD` prints `origin/main`, a
remote-tracking ref rather than a local branch, so substituting that
string whole is wrong for both uses: it would base the work branch on
the last fetched remote tip instead of the checkout's own HEAD, and it
would make teardown test remote history instead of the human's local
merge. The two differ by whatever has been fetched and not merged,
which is the normal state of a checkout rather than an edge case
(`git rev-list --left-right --count <default branch>...<remote>/<default branch>`
shows by how much). If the remote HEAD is unset, the remote is not
named `origin`, or `refs/heads/$name` does not resolve, the default branch
is confirmed with the human and never guessed. Everything below uses
the resolved local ref.

**Creation**, at the plan's first item only:

```bash
herdr worktree create --cwd <primary checkout> \
  --branch work/<slug> --base refs/heads/<default branch> \
  --label "<plan name>" --no-focus
```

`--base` pins where the work branch starts, and it takes the local ref
resolved above - fully qualified, so a tag or remote-tracking ref
sharing the name cannot win the lookup.
Herdr chooses the checkout path; read it and the ids to record from the
response - `.result.worktree.path`,
`.result.workspace.workspace_id`, `.result.root_pane.pane_id` - rather
than predicting them. If the primary checkout is not itself open as a
workspace, herdr opens it too, as the group's source workspace: the
orchestrator did not ask for it and never closes it.

**Recovery**, on every later invocation - the lookup first, a second
create never. Five arms, one discriminator each:

| Lookup result | Action |
|---|---|
| Entry with `open_workspace_id`, and that workspace's recorded `checkout_path` equal to the entry's `path` | Reuse that workspace as it is. |
| Entry with `open_workspace_id`, but the two paths disagree (the checkout moved) | Re-open by branch, as in the next arm; it rebinds the same workspace in place. |
| Entry without `open_workspace_id` (checkout on disk, not open) | `herdr worktree open --cwd <primary checkout> --branch work/<slug> --label "<plan name>" --no-focus` (`--path <checkout>` from the same entry is equivalent; the branch keeps one key for every arm) |
| No entry, and `git rev-parse --verify work/<slug>` succeeds (checkout removed, branch survived) | The creation command above, without `--base` |
| No entry and no branch | The plan's first item: create per above. |

Two behaviors hold the last three arms apart. A branch with no
checkout does not appear in `worktree list` at all, so git, not herdr,
answers whether the branch still exists; and `worktree open` needs an
existing checkout, returning `worktree_not_found` on a branch without
one - that is the fourth arm's signal, not an error to retry. On an
existing branch `worktree create` reuses it at its own tip and ignores
`--base`, which is what makes that arm safe.

**A moved checkout** is the one case where an open workspace is not
enough on its own, so it gets its own arm above. Renaming the branch
usually brings a `git worktree move` with it, to keep the path
matching the name. `worktree list` follows the move immediately, but a
workspace that was already open keeps recording the path it was opened
at, and herdr does not follow the move for it - which is exactly the
disagreement the second arm tests. The cost is not the live panes:
their shells followed the directory through the rename and report the
new path. It is any later command built from the stale record, and one
of those fails silently - a seat pane split with `--cwd` set to the
recorded path does not error, because herdr falls back to the home
directory, so the seat comes up rooted outside the repo with nothing
to signal it. Re-opening by branch repairs the record in place and
keeps the workspace id, its label and its panes; closing the workspace
first also works, but discards the id for no gain.

**Seat hosting.** A seat pane in a plan workspace is a sibling of that
workspace's pane, not of the orchestrator's - the orchestrator
normally sits in the primary workspace, and a seat split from its pane
would land in the wrong repo checkout:

```bash
herdr pane split --pane <plan workspace pane> --direction right \
  --cwd <plan checkout> --no-focus
```

Direction follows `herdr pane layout --pane <plan workspace pane>` as
in "Naming and panes"; the workspace's root pane stays a plain shell,
the anchor and the human's way in, so seats never take it over.
Everything else - naming, `agent start`, prompt via file, the settled
wait, exit classification, both kinds of blocked, toasts, pane
teardown - is unchanged.

**Status tokens.** `workspace report-metadata` carries tokens only;
`--state-label` belongs to `pane report-metadata`, not here. The
orchestrator reports the plan's coarse state whenever it changes:

```bash
herdr workspace report-metadata <workspace-id> --source plan-skills \
  --token status="<item> - <phase>"
```

with phase naming the gate the plan is at: `executor running`,
`validation`, `review round <N>`, `awaiting human`, `conformance`,
`reviewed - awaiting commit`, `done`. On 0.9.0 the panels render
names and labels, not metadata: these tokens are stored and
API-readable and no panel shows them (confirmed visually
2026-10-21, workspace tokens and pane tokens alike), so the
workspace label carries what the human must see and the tokens are
for machine readers; worth confirming again on a newer build.

**Teardown** is one command, and it is earned:

```bash
herdr worktree remove --workspace <workspace-id>
```

It closes the workspace, deletes the checkout, and always leaves the
branch. Two ways to earn it and no third:

- **Plan completion**: every breakdown item is `done <commit>` AND the
  work branch tip is contained in the local default branch
  (`git merge-base --is-ancestor work/<slug> refs/heads/<default
  branch>`, from the primary checkout - never
  `<remote>/<default branch>`, since what is being asked is whether
  the human's own merge has happened in this checkout, and a remote
  tip that has not taken the work branch would refuse teardown
  forever). Both halves are load-bearing: an earlier merge while items
  are still open fails the first, and after the last item's commit the
  tip has moved past any earlier merge, so the second fails until the
  human integrates that final state.
- **Abandonment**: an explicit human `[decision]` in the worklog.
  Nothing else substitutes for it.

Before removing, confirm every seat has settled and its pane is
closed. `worktree remove` closes the workspace's panes whatever is
running in them: a live seat or a running build dies silently, with no
refusal to catch the mistake. A checkout with uncommitted or untracked
files does refuse, with `dirty_worktree_requires_force`, and `--force`
discards that work - so the orchestrator shows the human
`git status --porcelain` from the checkout and forces only on their
word. Never `workspace close --group`: that takes the primary
workspace with it.

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

Herdr-hosted seats are exercised now too: the same claude-executes /
codex-reviews pairing, run inside herdr 0.9.0 on a real work item (the
plan-sync-publish-gate micro-plan's item 1, 2026-10-21, as the
herdr-seat-visibility plan's item 4), with the orchestrator a claude
session in the primary workspace and every seat a live herdr agent in
the plan's own worktree workspace. Entry points were verified current
before it began, since the exercise is meaningless against stale ones.

Witnessed across that run, each sampled rather than inferred:

- The worktree workspace as the plan's home: created at its first
  item, carrying every item and invocation since, and grouped under
  the repo (herdr reports it a linked worktree keyed to the primary
  checkout's `.git`). It survived both kinds of loss - a five-day
  pause with its seats still alive, and an accidental `workspace
  close`, after which the lookup read `<UNOPENED>` and `worktree open
  --branch` reopened the same checkout. One branch has had three
  workspace ids across the plan, which is why the lifecycle keys on
  the branch and never the id.
- Hosted seats end to end: claude executors at `bypassPermissions`,
  codex reviewer and conformance seats at `workspace-write` with the
  plan-dir writable root, prompt via file, settled-state waits, exit
  classification from the worklog entries, and `agent_session` read
  live for the claude session id (codex seats recorded none, which was
  accurate when observed and not the whole rule - see "Session record"
  and the integration edge below).
- Live input waits of both origins, Decision 10's path in full: one
  provoked (a reviewer seat started read-only so it would have to ask)
  and one natural (a conformance seat hitting the nix cache-lock edge
  below). Each time `agent get` reported `blocked`, `agent read
  --source visible` rendered the dialog, the orchestrator surfaced it
  without answering, the human's answer was written as a worklog
  `[decision]` before the seat was continued, the keys were relayed,
  and the seat returned to working.
- A `[blocker]` exit on the hosted path, the under-context path again:
  the executor walled on a design choice the documents withheld and
  changed nothing, the human named the mechanism in a `[decision]`,
  and a steering resume of the same live agent implemented it.
- In-process subagent lifecycle from the orchestrator's own hook, which
  had never fired on that machine before the exercise (its state root
  did not exist), sampled on its pane through `herdr api snapshot`
  while a seat worked beside it: a single child's token appearing and
  clearing with its state file; a long child holding its token unbroken
  through a ~95s event-silent tool call, across samples 12s apart; and
  two children live at once, two distinct tokens in every 2s sample for
  32s, one changing tool while the other held, then both clearing. A
  child's label is its agent type for its whole life unless it reaches
  its parent's Stop, where the task description arrives. What that
  establishes is the lifecycle, read through the API - not visibility:
  those were tokens, and tokens render nowhere on this build (below).
  The hook now also summarises its live roster into one
  `--display-agent` override, which is the half a human can see.
- The headless fallback, run rather than assumed: with `HERDR_ENV` and
  the caller context vars unset the selection check chose the headless
  recipes, and `claude -p ... --output-format json` returned its
  session id with `is_error: false`.
- Both of Decision 10 and 11's human-facing signals, each confirmed by
  the human looking at them and each correcting the recipe written for
  it. The seat-completion toast fired on a blocked settle, invisible
  three times until the orchestrator learned a toast is a TUI corner
  overlay taking `--position`, then seen. The `[blocker]`-exit pane
  mark was set as specified, with `--state-label` and `--token` both
  stored and API-readable, and the agents panel showed nothing;
  `--display-agent` on the same pane changed the entry and was seen.
  Both recipes above now carry the corrections.
- The panels, which "Status tokens" above asked be confirmed once: on
  0.9.0 they render names and labels, not metadata. Workspace tokens
  were stored and API-readable at the same moment they were absent
  from both panels, pane tokens and state labels likewise; the
  workspace label and the agent name are what reach the human, and a
  sidebar narrow enough truncates even the label. Keep what the human
  must see in a name or a label.

What that run does not establish:

- The orchestrator was claude. Both plan-implement adapters carry the
  workspace lifecycle and the parity test keeps them symmetric, but a
  codex orchestrator hosting seats in herdr stays unexercised.
- Teardown of a real plan's workspace at plan completion. The full
  cycle has been exercised only on a throwaway; no real plan has
  earned it yet.
- Subagent presence as something the human saw. The lifecycle above was
  sampled through the API, and the `--display-agent` summary that
  replaces it was driven against live herdr with synthetic hook events
  (roster of one, overlap of two, label upgrade at the parent's Stop,
  per-child clearing, the compaction guard, and coexistence with the
  blocked mark) rather than by a run with real children in a panel the
  human was watching. Nor is the hook in that tree the installed one:
  what makes an edit live depends on how the machine links authored
  files. On the verified setup they are linked out of store - the
  installed hook's link chain resolves into the primary checkout - so
  merging the work and pulling there is what makes the new version
  live, with no rebuild; a rebuild is needed only when a *new* link
  appears. On a machine without that option the installed copy is a
  store path and a rebuild is the only route. Either way, until a live
  hook reports real children and the human confirms the panel, API
  token presence is not the criterion met - which is why the contract
  is pinned by `tests/subagent-hook.test.sh` rather than by one
  hand-driven run.

Not yet witnessed: an abnormal exit (the classification path is
untested live). Multi-reviewer panels (see "Panels" and the panel
addendum in ROLES.md) remain wired but unexercised; expect rough edges
the first time and fix them here.

Rough edges from the exercises, filed:

- Spawning `claude -p` from an orchestrator harness with permission
  prompts: the auto-mode classifier blocked the executor spawn until a
  `Bash(claude -p*)` allow rule was added, and the prompt had to be
  delivered via stdin - `$(cat ...)` command substitution stayed
  blocked. So `bypassPermissions` on the executor is not the whole
  story; the orchestrator side needs the allow rule and stdin
  delivery. Checked again on 2026-10-21 under herdr: the
  headless spawn passed with no such rule, while the hosted `herdr
  agent start` had to be allowed explicitly, so the classifier has
  moved and the two spawn forms gate differently. A statement about
  those harnesses on those days, not about the classifier in general.
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
  sandbox cannot validate" rather than left to judgment. Hit again on the
  hosted path (2026-10-21) by a codex conformance seat, where it
  arrived as a live input wait; the answer filed here is the one the
  human chose, decline the escalation and judge from the
  orchestrator's recorded gate evidence.
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
- Closing the last seat pane closes the workspace. "The plan workspace"
  promises the root pane stays a plain shell, the anchor and the
  human's way in, but says nothing about it already being gone: five
  settled seats were closed in a workspace whose root pane no longer
  existed, and the workspace went with them. Nothing durable was lost
  (checkout on disk, branch intact, the entry `<UNOPENED>`, reopened
  by branch), but either the root pane needs protecting or seat
  teardown needs to check for the anchor first.
- `agent prompt`'s `agent_blocked` guard is real, confirmed by accident
  during the herdr run: it refused a blocked seat before sending any
  input. Worth stating precisely, because the looser reading ("agent
  prompt protects you from dialogs") is wrong - a codex upgrade dialog
  that appeared after `agent start` had already reported idle was
  prompted into, which is a race around the guard rather than an
  absence of it.
- A "no" option that redirects needs the redirection supplied. codex's
  decline reads "No, and tell Codex what to do differently (esc)";
  relaying the keys that select it interrupted the turn and left the
  seat stalled with nothing written, until it was re-prompted with the
  instruction the option asks for. Relaying the human's exact choice is
  not the whole relay when that choice is a redirect.
- Read-only is not a variant of the codex seat recipe. A reviewer seat
  set read-only (to provoke a live input wait) could not write the one
  file its role permits: under read-only the
  `sandbox_workspace_write.writable_roots` override riding alongside it
  does nothing. The recipe is `--sandbox workspace-write` plus the
  writable root; provoke a wait some other way.
- A missing output file is not evidence of an abnormal seat until the
  seat's state has been read. In the same run an absent review file was
  read as a seat that had settled without writing; the wait had
  returned on `blocked`, and the seat had finished its review and was
  parked at an approval dialog.
- The two human-facing signals this plan specified were both written in
  flags that render nothing. A toast is an overlay drawn in a corner of
  the herdr TUI, not a macOS notification: `notification show` without
  `--position` lands wherever the build defaults to, and three calls
  that each returned `shown: true` reached nobody before the flag was
  found. The blocker mark was `--state-label` plus `--token`, both
  stored and API-readable, and the agents panel showed no blocked text
  at all; `--display-agent` renders because the panel draws the agent
  name. Generalised: this build surfaces names and labels, not
  metadata. Both recipes above are corrected; the lesson for the next
  one is that an API returning `shown: true` or storing a token is
  proof the call was accepted, never that a human saw anything. The
  subagent hook was the third instance of the same mistake, caught in
  review rather than by looking: it reported children as tokens only,
  so its own evidence could only ever be an `api snapshot` read. It now
  sets a display-agent summary beside the tokens, pinned by a test that
  drives the hook against a stub herdr and fails if the rendered half
  disappears again. That first fix then reintroduced, at the display
  layer, the bug the hook had already solved at the state layer: state
  is keyed per pane AND session because a nested child session shares
  its parent's pane, while the override is keyed per pane and source,
  so a nested session ending cleared a parent's live children. Caught
  in review again. When a correction adds a second layer of state,
  check whether the first layer's keying was load-bearing. Worth knowing for any
  such pair: metadata is stored per source and the panel shows the most
  recent writer, with a cleared source falling back to another's stored
  value, so the subagent summary and the blocked mark above coexist on
  one pane - whichever wrote last shows, and clearing the summary
  restores the mark (measured 2026-10-21).
- A reported session id took three independent preconditions, and each
  of the first two looked sufficient until measured. `herdr
  integration install codex` moved status to `current (v8)` and a seat
  spawned after it still returned `agent_session=None`, because codex
  0.163.0 parks the newly registered SessionStart hook behind a trust
  review ("1 hook needs review before it can run", Installed 1 /
  Active 0). A human trusted the hook and a freshly spawned seat still
  returned `None`, at start and across four polls. One prompt later
  the same seat reported its thread id. So: installed, trusted, and
  having taken a turn - with the third the one no configuration
  implies, since a thread has no id before there is a conversation.
  The operational consequence is in "Session record": for a hosted
  codex seat the id is readable after the first prompt, not at
  `agent start`, so an orchestrator that reads `agent get` once at
  spawn records "no thread id surfaced" wrongly. Every codex
  `[session]` id entry in this plan was written that way; they are
  honest records of what was observed then, and the rule they implied
  was wrong.
- That same probe found the bound on `agent prompt`'s guard. herdr
  0.9.0 did not classify codex's hook-trust modal as `blocked`: the
  seat reported `idle` with `interactive_ready: true` at `agent start`
  and `done` afterwards, so the `agent_blocked` refusal could not fire,
  `agent prompt --wait` was accepted and timed out, and the prompt text
  never reached codex. The guard protects the states herdr calls
  blocked and nothing else, which is the same shape as the codex
  upgrade dialog above. A seat that will not take a prompt is read with
  `agent read --source visible` before anything is resent.
- Claude Code renders a suggested next prompt in an idle seat's input
  box, visually indistinguishable from text a human typed; an
  orchestrator reading a pane mistook one for human steering. Nothing
  in a pane transcript proves a human typed it, which is why steering
  arriving as a worklog `[decision]` is load-bearing rather than tidy.
