# plan-skills

A plan-driven workflow for working with AI agents, built on one rule:
agents never talk to each other directly. An executor agent does the
work, an impartial reviewer agent (a different LLM, in its own session)
judges it against plan documents, and everything between them goes
through markdown files a human can audit. The human gates every round
and owns every commit.

## The lifecycle

```
plan-create <name>           interview -> plan.md + breakdown.md
                             -> AI design review loop -> your sign-off

plan-implement <plan-dir>    next work item: implement
  -> plan-item-review        -> impartial review loop over the item
  -> plan-sync               -> plan docs reconciled with what landed

plan-conformance-pass        whole-delivery audit against the plan

plan-archive <plan-dir>      finished plan moves to the archive repo
                             (provenance stamp, index, tombstone)
```

`plan-item-review` and `plan-conformance-pass` also run standalone: any
finished work with a source-of-truth doc can be reviewed, plan or not.

## Driving it

Each command above is a skill both agent CLIs ship: type
`/plan-create` in claude code, `$plan-create` in codex (the `$` mention
popup lists them), and either agent orchestrates the same protocol from
these files.
You will be prompted for whatever is missing: plan directory, plan doc
paths, reviewer profile (which LLM reviews, e.g. `codex`, `codex:<model>`,
`claude`).

What to expect while a loop runs: the orchestrator pauses after every
reviewer round so you can read the review file before anything is acted
on; open items get executor responses appended under them and only the
reviewer closes them; a disagreement that survives 3 rounds is escalated
to you; no agent commits, pushes or opens a pull request on its own
initiative, and the work reaches your default branch only through a
pull request - opened by you, or by the orchestrator when you tell it
to, and then left open for you. Telling an agent to push or open a PR
never authorizes it to merge one: that takes your word on the PR in
front of you, after you have read it.

## The files

In this directory:

- `PROTOCOL.md` - the seats, the loop, isolation rules, CLI profiles.
- `ROLES.md` - the prompt templates each spawned seat receives.
- `ARTIFACTS.md` - the plan directory layout: plan.md, breakdown.md,
  the append-only worklog, the approval gate, and the lavish review
  surface (`plan-publish` / `plan-feedback`).

Per plan, everything lives in one directory (default
`docs/plans/<name>/`): the two plan docs, `worklog.md`, and every
review and conformance file - the complete audit trail of how the work
came to be. When the work is done, `plan-archive` moves that directory
to your archive repo (set its local path in
`~/.config/dotfiles-local/plan-archive-root`), where plans from every
project accumulate into a searchable corpus of prior art.
