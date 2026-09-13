# plan-skills artifacts

Conventions for the documents the plan-* family creates and maintains.
PROTOCOL.md defines who talks to whom; this file defines what lives
where. The markdown files below are the only source of truth - for
humans and agents alike.

## The plan directory

One directory per plan, `docs/plans/<plan_name_slug>/` by default (any
path works; it is an argument). Whether the repo tracks it is the repo
owner's call. Contents:

- `plan.md` - strategy: what and why.
- `breakdown.md` - execution: the ordered work items.
- `worklog.md` - append-only history of everything that happened.
- `plan_review.md` - the design review (plan-create's loop).
- `<work_item_slug>_review.md` - one per item (plan-item-review).
- `<scope_slug>_conformance.md` - conformance audits.
- `ARCHIVED.md` - provenance stamp, added at archive time (below).

## plan.md

Opens with a status line:
`> **Status:** draft | in design review | approved YYYY-MM-DD`.

Required sections:

- **Intent**: the human's goal, in terms they would recognize as theirs.
- **Decisions**: a table of every decision from the interview and the
  sign-off. Decisions are final; implementation never re-litigates them.
  Changing one after approval is a human call, recorded in the worklog.
- **Scope**: in, out, and stretch - explicitly.
- **Risks**: each with severity and mitigation.
- **Success criteria**: how everyone knows it is done and working.
- **Open questions**: what needs exploration before or during
  implementation (these are questions, not undecided decisions).

Architecture level throughout: what and why. The how belongs to the
implementation sessions.

## breakdown.md

Opens with a status line:
`> **Status:** <n>/<m> items done; last synced YYYY-MM-DD (<commit>)`.

Ordered work items. Each carries: goal, blocking edges (the items that
must land first; none means it can start now), validation, exit
criteria, and status (`pending` | `in progress` | `reviewed` |
`done <commit>`). `reviewed` means the item passed its review loop and
awaits the human's commit; only an existing commit makes it
`done <commit>`.

Drafting rules:

- Lean toward vertical slices: a narrow but complete path through every
  layer the item touches, demoable or verifiable on its own, sized to
  one session and one PR. When a slice must split, the pieces compose
  through blocking edges and the group gets a verifiable end point.
  Do not force a slice where one is not feasible.
- Prefactoring lands first, as its own item.
- Wide mechanical refactors (one change, whole-codebase blast radius)
  are the exception: sequence them expand-contract. Expand adds the new
  form beside the old; migrate moves call sites in batches sized by
  blast radius, each batch its own item blocked by the expand; contract
  deletes the old form in an item blocked by every batch.

## worklog.md

Append-only, chronological. One entry per line or short block:
`- YYYY-MM-DD [type] ...`. Types:

- `[done]` - an item landed: commits, how it was verified.
- `[decision]` - a decision made or changed after the plan was written,
  with rationale. Supersede by appending a new entry that references the
  old one; never edit or delete old entries.
- `[blocker]` - something is stuck: what, and what unblocks it.
- `[handoff]` - a session stopping point: state of the work, what is
  incomplete, what the next session should do first.

`plan-implement` reads the tail of the worklog before starting; a
`[handoff]` there is the previous session's baton. This one file
replaces separate state, progress, and handoff documents.

## Approval gate

The status in plan.md flips to `approved` only on the human's explicit
sign-off, recorded as a `[decision]` worklog entry. `plan-implement`
refuses to run against a plan that is not approved. After approval the
plan is frozen: changes happen as `[decision]` entries or an explicit
re-review, never as silent edits.

## Archival

Plans stay in their repo while the work is underway; a finished plan
moves to an archive repo, where past plans from every project form one
searchable corpus of prior art (plan-create's interview should point
there).

- **Terminal gate**: archive only when every breakdown item is
  `done <commit>` and the latest conformance file has no open items.
  Anything short of that is the human's call, recorded as a
  `[decision]` worklog entry before archiving.
- **Destination**: an argument; the default is read from
  `~/.config/dotfiles-local/plan-archive-root` (one line: the absolute
  path to a local clone of the archive repo). `dotfiles-local` is the
  machine-local override directory - unmanaged and writable, unlike
  this managed core directory. Ask when neither exists.
- **Stamp**: before the move, add `ARCHIVED.md` to the plan directory:
  source repo (path and remote), the commit range the items landed as,
  created / approved / archived dates, a short outcome paragraph
  against the plan's Intent, and the plan-skills core version (the git
  commit of the checkout `~/.config/plan-skills` resolves into, or the
  nix store path when it does not).
- **Layout**: the plan directory moves to
  `<archive repo>/<source repo name>/<plan_name_slug>/`, and one index
  line is appended to the archive repo's README.md.
- **Append-only**: the archive never loses history. If the destination
  directory already exists (a reused slug, or two source repos sharing
  a basename), stop and ask the human before copying anything; never
  overwrite or merge into an existing entry, and leave the source
  untouched until the collision is resolved.
- **Tombstone**: in the source repo, one line appended to
  `docs/plans/ARCHIVE.md` - plan name, archive date, destination, final
  commit - and the plan directory is removed. No stub directories.
- The human owns the commits in both repos, as always.

## Artifacts (the human review surface)

Humans review best where they can comment inline, so plan.md (and
breakdown.md when useful) is published as a markdown artifact: a
disposable render of the file, never a second master. Republish the same
artifact (same URL) at checkpoints: when the design review closes, at
sign-off, and after each plan-sync. Inline comments flow back through
the orchestrator: each thread becomes an edit to the markdown or a
recorded disagreement in the relevant review file, then gets a reply and
is resolved. Never edit content in the artifact itself; if the render
and the file disagree, the file is right and the artifact is stale.

Publishing artifacts is a claude capability. When the orchestrator
cannot publish (codex), skip the render: the human reviews the markdown
directly and the rest of the flow is unchanged.
