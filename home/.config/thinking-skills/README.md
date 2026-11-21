# thinking-skills

Three skills for the thinking that happens before the work: two
interviews and one writing reference. They share no protocol - each
is a self-contained method in its own file here, and the per-CLI
skill directories are thin adapters that assign the role and point
at the file.

## The three

- **`grilling`** - the stress-test interview. You already have a
  plan, a decision or an idea; this one maps it as a design tree and
  interviews you round by round until no assumption is left
  unstated. Facts it looks up itself; decisions are yours.
- **`interview-me`** - intent extraction for an underspecified ask.
  One question at a time, each with the agent's guess attached,
  until it can predict your reactions; ends in a six-field
  statement of intent you confirm with an explicit yes.
- **`writing-for-agents`** - a reference for authoring any document
  an agent consumes: context pointers, the context/cognitive load
  budgets, the information hierarchy, completion criteria, leading
  words, pruning. Its skill-specific mechanics sit in a companion
  file read only while writing a skill.

## Which interview

The split is what you bring to it:

- You have something to poke holes in - a plan, a design, a call
  you have already made - and want it stress-tested: `grilling`.
  The whole grill vocabulary belongs to it.
- You have an ask nobody has pinned down yet - "build me X", with no
  who, why or definition of done - and the thing to extract is what
  you actually want: `interview-me`.

Both may end by offering `plan-create` when what you agreed is a
piece of work worth planning. Neither starts the work itself.

## Driving them

Each is a skill both agent CLIs ship: type `/grilling` in claude
code, `$grilling` in codex (the `$` mention popup lists them). The
methods are identical across the two; only the asking conventions
differ, since codex carries at most three questions per ask, so
`grilling` presents a frontier larger than that in chunks.

Working inside this repo's own checkout, an agent CLI discovers the
authored copies under `home/.claude/skills/` and `home/.codex/skills/`
as directory-scoped skills on top of the installed ones in
`~/.claude/skills/` and `~/.codex/skills/`, so each skill appears
twice - the scoped duplicate listed under a `home:` prefix. That is
an artifact of authoring the skills in the same repo that ships
them, already true of the `plan-*` family. Invoke the unscoped one
unless you are deliberately testing an edit in the checkout.

## The files

- `grilling.md`, `interview-me.md` - one method per interview.
- `writing-for-agents.md` plus `writing-for-agents-mechanics.md` -
  the writing reference and its skill-mechanics companion.

## Provenance

Each method is distilled - not copied - from an upstream skill:
rewritten to this repo's conventions and density, with the method
itself preserved. Upstream mains as of 2026-10-22:

- `grilling` and `writing-for-agents` - `mattpocock/skills` (MIT),
  commit `5beb35b040e3de97e54fa9e386d7e42d15c295c2`.
- `interview-me` - `addyosmani/agent-skills` (MIT),
  commit `aeac41d4d005999432bb7312f7ff06383a91d59d`.

Upstream's `grill-me` alias is not shipped: its trigger phrases fold
into `grilling`, which this repo leaves model-invocable as well as
typeable.
