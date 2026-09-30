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
the plan directory, worklog, approval gate, artifact checkpoints - are
defined in ARTIFACTS.md.

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
  The review file stays the channel of record for review items and
  responses; the worklog is the channel of record for everything else
  (outcomes, sessions, evidence, steering).

## The executor seat (plan-implement)

The orchestrator spawns the executor as a fresh CLI process with the
`executor` template, then judges the outcome from files only - the
diff and the worklog tail - never by tailing live output.

- **Session record**: `[session]` entries come in pairs. Immediately
  before every spawn AND every resume, the orchestrator appends the
  boundary entry - item, seat, profile, invocation number - which is
  the classification boundary below. When the CLI reports the session
  id, the orchestrator appends the id entry - invocation number,
  session id - which is the resume pointer (a separately-invoked
  plan-item-review resumes from the item's latest id entry). Codex
  prints its thread id on the first stdout line, so the id entry can
  land while the seat still runs; `claude -p` reports it in the JSON
  result at exit. A boundary with no id entry (a crash before the id
  was reported) has no resumable session: recovery is a fresh spawn.
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
  plan branch and recovered rather than recreated; the orchestrator's
  own validation and diff inspection move into that checkout too,
  while the plan documents stay in the primary checkout. The full
  lifecycle - creation, the recovery arms, status tokens, the teardown
  gate - is "The plan workspace" under Profiles.

## The loop (plan-item-review)

1. **REVIEW**: orchestrator spawns the reviewer with the `review-initial`
   template. Reviewer writes the review file.
2. **PAUSE**: orchestrator summarizes the review to the human and waits.
3. **ADDRESS**: orchestrator resumes the executor session (the item's
   latest `[session]` id entry) with the `executor-address` template;
   the executor fixes and responds to every open item.
4. **GATE**: before any reviewer round is spent, the orchestrator
   classifies the ADDRESS invocation's exit per "The executor seat"
   (blocked and abnormal go to the human) and re-runs the item's
   validation line - after every implemented exit, unconditionally;
   red follows the validation gate (evidence, resume, cap), not the
   review loop. Only an implemented exit with green validation
   proceeds.
5. **VERIFY**: orchestrator resumes the same reviewer session with the
   `review-verify` template. Reviewer closes what is adequately addressed,
   may add new items for problems the fixes introduced.
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
reviewer plays principal engineer on a design document. Differences from
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
  needs.

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
  --state-label idle="blocked: <summary>" \
  --state-label done="blocked: <summary>" \
  --token blocked="<summary>"
```

and clears the mark on the steering resume:

```bash
herdr pane report-metadata <pane-id> --source plan-skills \
  --clear-state-labels --clear-token blocked
```

**Toasts.** When a seat invocation settles after running longer than
the threshold (default 60s), or settles blocked at any duration, the
orchestrator - the only party that knows a seat settled - raises:

```bash
herdr notification show "<seat name>: <settled state>" \
  --body "<item>: <one-line outcome>" --sound done
```

(`--sound request` when it settled blocked).

**Session record.** The `[session]` boundary entry is unchanged. The
id entry records the herdr identities in place of a CLI-reported id:
agent name, workspace id, pane id, worktree path, and branch. Whether
a seat also gets its native session id depends on that agent's herdr
integration (`herdr integration status`): an installed integration
reports the id through `agent_session`, read live from `herdr agent
get <name>` (`.agent_session.value`) - no wait-for-exit. The claude
and codex integrations are both session-identity-only; seat state
stays screen-detected regardless. On the verified setup claude's is
installed (v9), so claude seats record the id; codex's is not, so no
codex thread id is surfaced there and none is recorded - a fact
about that machine's integrations, not about herdr. Installing it
(`herdr integration install codex`; it writes under `~/.codex`, so
it is the human's call) would surface the codex thread id the same
way and let herdr's own session restore resume the pane
(`codex resume <id>`). Either way the id is identity for the record:
recovery stays fresh-spawn per the Resume rule, and scraping
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

Inside herdr a plan gets one worktree workspace on one branch,
`plan/<slug>` (the plan directory's own slug), created at the plan's
first work item and persisting as the plan's home across items, human
pauses, and orchestrator invocations. Hosted seats run there; the
orchestrator runs its validation and diff inspection in that checkout.
Plan documents stay in the primary checkout - the checkout the plan
directory lives in, where the human works - and are written there by
absolute path, codex seats via the writable root above. Outside herdr
none of this applies: the classic single-checkout flow is unchanged
and what the orchestrator offers at an item is a plain branch.

**The branch is the only durable identity.** Workspace ids are not
stable across teardown or restarts, and a checkout path can resolve
through symlinks (`/tmp` vs `/private/tmp`), so neither is a lookup
key. Every lookup is one command against the primary checkout:

```bash
herdr worktree list --cwd <primary checkout>
```

matched on `.result.worktrees[] | select(.branch == "plan/<slug>")`.

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
string whole is wrong for both uses: it would base the plan branch on
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
  --branch plan/<slug> --base refs/heads/<default branch> \
  --label "<plan name>" --no-focus
```

`--base` pins where the plan branch starts, and it takes the local ref
resolved above - fully qualified, so a tag or remote-tracking ref
sharing the name cannot win the lookup.
Herdr chooses the checkout path; read it and the ids to record from the
response - `.result.worktree.path`,
`.result.workspace.workspace_id`, `.result.root_pane.pane_id` - rather
than predicting them. If the primary checkout is not itself open as a
workspace, herdr opens it too, as the group's source workspace: the
orchestrator did not ask for it and never closes it.

**Recovery**, on every later invocation - the lookup first, a second
create never. Four arms, one discriminator each:

| Lookup result | Action |
|---|---|
| Entry with `open_workspace_id` | Reuse that workspace as it is. |
| Entry without `open_workspace_id` (checkout on disk, not open) | `herdr worktree open --cwd <primary checkout> --branch plan/<slug> --label "<plan name>" --no-focus` (`--path <checkout>` from the same entry is equivalent; the branch keeps one key for all four arms) |
| No entry, and `git rev-parse --verify plan/<slug>` succeeds (checkout removed, branch survived) | The creation command above, without `--base` |
| No entry and no branch | The plan's first item: create per above. |

Two behaviors hold those arms apart. A branch with no checkout does not
appear in `worktree list` at all, so git, not herdr, answers whether
the branch still exists; and `worktree open` needs an existing
checkout, returning `worktree_not_found` on a branch without one -
that is the third arm's signal, not an error to retry. On an existing
branch `worktree create` reuses it at its own tip and ignores `--base`,
which is what makes the third arm safe.

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
`reviewed - awaiting commit`, `done`. Whether a given herdr build's
panels render workspace tokens or only labels is worth confirming
visually once; the label carries the plan name either way.

**Teardown** is one command, and it is earned:

```bash
herdr worktree remove --workspace <workspace-id>
```

It closes the workspace, deletes the checkout, and always leaves the
branch. Two ways to earn it and no third:

- **Plan completion**: every breakdown item is `done <commit>` AND the
  plan branch tip is contained in the local default branch
  (`git merge-base --is-ancestor plan/<slug> refs/heads/<default
  branch>`, from the primary checkout - never
  `<remote>/<default branch>`, since what is being asked is whether
  the human's own merge has happened in this checkout, and a remote
  tip that has not taken the plan branch would refuse teardown
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
and an orchestrator that authored none of either item's changes. Not
yet witnessed: an abnormal exit (the classification path is untested
live). Flipped reviewer seats and multi-reviewer panels (see "Panels"
and the panel addendum in ROLES.md) remain wired but unexercised;
expect rough edges the first time and fix them here.

Rough edges from the exercise, filed:

- Spawning `claude -p` from an orchestrator harness with permission
  prompts: the auto-mode classifier blocked the executor spawn until a
  `Bash(claude -p*)` allow rule was added, and the prompt had to be
  delivered via stdin - `$(cat ...)` command substitution stayed
  blocked. So `bypassPermissions` on the executor is not the whole
  story; the orchestrator side needs the allow rule and stdin delivery.
- The codex `workspace-write` sandbox cannot run nix builds (store
  cache writes are denied), so codex reviewer and conformance seats
  cannot reproduce build-dependent validation lines; they judge from
  the orchestrator's gate evidence in the worklog instead.
- ARTIFACTS.md defines no worklog type for the validation gate's
  evidence; ad-hoc `[validation]` entries were used and read fine.
  Candidate for a future ARTIFACTS.md addition.
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
- The orchestrator wrote `[done]` for the tmux item's review-loop and
  conformance completions while the commit was still pending, against
  ARTIFACTS.md's committed-only meaning; both entries are superseded
  by an append-only `[decision]` in that worklog. Pre-commit
  milestones take `[handoff]` (or the entry type of the event itself);
  `[done]` is reserved for landed work.
