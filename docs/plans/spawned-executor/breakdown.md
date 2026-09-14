# Spawned executor - breakdown

> **Status:** 2/2 items done; last synced 2026-09-13 (de68662)

## Item 1: Protocol, roles and adapters land atomically

- **Goal:** The plan-skills core and the six affected adapters describe
  and drive the spawned-executor flow, in one coherent change:
  PROTOCOL.md (seats, the implementation-scoped hard rule with the
  design-review exception preserved, the loop with spawn / exit
  taxonomy / validation gate with evidence handoff and resume caps /
  `[session]`-based resume contract, profiles with executor grants,
  status), ROLES.md (spawned executor template with
  `[implemented]`/`[blocker]` conventions and resume wording),
  ARTIFACTS.md (the `[implemented]` and `[session]` worklog types),
  the plan-implement + plan-item-review adapters for claude and codex
  rewired to spawn/resume the executor and report from the diff and
  worklog, and the plan-create adapters extended to record executor and
  implementation-reviewer profiles. Atomic because adapters tell
  orchestrators to read the core at runtime, so a split landing would
  leave adapters and protocol contradicting each other.
  **Transition rule:** this item is the last orchestrator-executed one -
  implemented and reviewed under the old protocol, in one session that
  does not re-read the core mid-loop; recorded as a `[decision]` in the
  worklog when it starts.
- **Blocking edges:** none.
- **Validation:** `ruby -ryaml -e 'ARGV.each { |f| YAML.safe_load(File.read(f).split("---")[1]) }' home/.claude/skills/plan-create/SKILL.md home/.claude/skills/plan-implement/SKILL.md home/.claude/skills/plan-item-review/SKILL.md` exits 0; `grep -c "bypassPermissions" home/.config/plan-skills/PROTOCOL.md` >= 1; `grep -c "\[implemented\]" home/.config/plan-skills/ARTIFACTS.md` >= 1; human: all six adapters and the core agree the orchestrator never implements in the implementation loops, with the design-review exception stated.
- **Exit criteria:** A reader of PROTOCOL.md + ROLES.md + ARTIFACTS.md
  alone can spawn, monitor, classify exits, validate with evidence
  handoff, and resume an executor without consulting this plan; no
  adapter or protocol text says the orchestrator implements in the
  implementation loops (the design review's orchestrator-as-editor
  wording stays, explicitly scoped).
- **Status:** done 2f4aa63

## Item 2: End-to-end exercise on a real work item

- **Goal:** Prove the flow, not the prose. First verify activation of
  everything the exercise will invoke: `~/.config/plan-skills` AND the
  adapters (`~/.claude/skills/plan-implement`, `plan-item-review`,
  `plan-create`, and their `~/.codex/prompts` twins) all resolve to
  item 1's updated content (this machine live-links them; a
  store-managed consumer would need a rebuild first - and a new link
  needs a rebuild even here), and the orchestrating session for the
  exercise is started fresh so it loads the updated adapter text. Then pick a small real work item from the repo's live backlog
  (open question in plan.md, resolved at implement time), run the new
  plan-implement end to end: spawned executor (default `claude`
  profile) implements from docs alone, writes
  `[implemented]`/`[blocker]` worklog entries, orchestrator classifies
  the exit and runs the validation gate. Required evidence, forced
  where it does not occur naturally: one validation-red -> evidence in
  worklog -> resume -> green; one under-context probe (the item's docs
  deliberately omit one needed fact; the executor must wall at it with
  a `[blocker]`, the docs get repaired, the session resumes); at least
  one resume of the executor session for ADDRESS if the review opens
  items, otherwise the validation-red resume stands as the resume-
  mechanics evidence and is recorded as such. Then the item goes
  through plan-item-review. Record what the exercise proved - and
  every rough edge fixed or filed - in PROTOCOL.md's Status section.
- **Blocking edges:** item 1.
- **Validation:** human: the orchestrator authored none of the
  exercised item's changes (every file change came from the executor
  process; the orchestrator's writes are prompts, worklog
  `[session]`/`[decision]`/evidence entries, and reports - judged from
  the transcript); the item's own review loop closes;
  `grep -n "exercised" home/.config/plan-skills/PROTOCOL.md` shows the
  spawned path recorded.
- **Exit criteria:** Every success criterion in plan.md holds, each
  witnessed by the exercise or explicitly forced, including the exit-
  taxonomy and resume evidence listed in the goal.
- **Status:** done de68662 (review loop closed at verify round 1 after an
  ADDRESS round; conformance clean 2026-09-13. Deviations from draft:
  the under-context evidence came from a second micro-exercise, the
  herdr runtime cleanup, after the tmux probe turned into
  privilege-wall evidence; the tmux validation-red resume plus the
  ADDRESS resume together cover the resume mechanics)
