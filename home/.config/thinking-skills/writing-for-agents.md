# writing-for-agents

A reference for writing any document an agent consumes: a skill, an
`AGENTS.md` or `CLAUDE.md`, a protocol file reached by a pointer.
The packaging differs; the writing does not. The same levers make
each one predictable, because what repeats across runs is the
*process* the document drives, not the output it produces.

When the document is a skill, the frontmatter, invocation and router
mechanics live next door in `writing-for-agents-mechanics.md`; read
that file then, and only then.

## Context pointers

A **context pointer** is a reference held in the agent's context
that names out-of-context material and encodes the condition for
reaching it. A skill's description is one; a line in `AGENTS.md`
naming a doc is the same object. The pointer's *wording*, not its
target, decides whether and how reliably the agent reaches the
material: a must-have target behind a weakly worded pointer is a
variance bug. Sharpen the wording first; inline the material only if
sharpening fails.

A pointer does two jobs - state what the material is, and list the
**branches** that should trigger reaching it (a branch is a distinct
case the document handles, so different runs take different paths
through it). Every word of an always-loaded pointer costs on every
turn, so it earns harder pruning than the body: front-load the
leading word, keep one trigger per branch (synonyms that rename one
branch are one branch written twice), and cut identity the body
already carries.

## The two loads

Every document and pointer spends one of two budgets.

- **Context load** is the cost of always-loaded material on the
  agent's window: an `AGENTS.md` line, a skill description, anything
  sitting in context every turn, spending tokens and attention
  whether or not it fires.
- **Cognitive load** is the cost on the human: which documents
  exist, and when to reach for each. The human is the index. Not a
  cost to minimise - it is the price of human agency. Spend it where
  human judgment matters and remove it where it does not.

Material reached only through a pointer escapes context load at the
price of the pointer's own line; material with no pointer at all
rides entirely on cognitive load.

## Information hierarchy

A document is built from two content types: **steps** (the ordered
actions the agent performs) and **reference** (definitions, rules
and facts consulted on demand). They mix freely - all steps (a
recipe), all reference (a review's rules, this file), or both. The
core decision is where each piece sits on the **information
hierarchy**, a ladder ranked by how immediately the agent needs it:

1. **In-file step** - the primary tier: what the agent does, in
   order.
2. **In-file reference** - consulted on demand. Often a legitimately
   flat peer-set (every rule of a review on one rung), which is a
   fine arrangement, not a smell.
3. **Disclosed reference** - pushed into a separate file behind a
   context pointer, loaded only when the pointer fires. Spans a
   sibling file in the same directory through fully external
   reference that any document can point at.

Push too little down and the top bloats; push too much and you hide
material the agent needs. That tension is the whole decision.

**Progressive disclosure** is the move down the ladder, out of the
main file and behind a pointer, so the top stays legible. Not
primarily a token optimisation: it is how the hierarchy is
protected. Branching is the cleanest disclosure test - inline what
every branch needs, disclose what only some branches reach. In a
document with steps, in-file reference that should have been
disclosed buries them and turns attending to them into a coin flip:
a variance lever, not only a legibility one.

**Co-location** is the within-file companion. Where the ladder
decides how far down a piece sits, co-location decides what sits
beside it once there: keep a concept's definition, rules and caveats
under one heading rather than scattered, so reading one part brings
its neighbours along. The test is that the document reads like
documentation written for the agent; grouped material reads that
way, scattered material does not. (Distinct from duplication, which
repeats one meaning in two places; scattering fragments one meaning
across many.)

**Sprawl** is the failure mode here: a document simply too long,
even with every line live and unique. Attention thins across the
excess and every extra line is one more to keep relevant. The cure
is the ladder - disclose reference behind pointers, and split by
branch or sequence so each path carries only what it needs.

## Steps and completion criteria

Every step ends on a **completion criterion**, the condition that
tells the agent the work is done. Two properties make it a lever.

**Clarity**: can the agent tell done from not-done? A vague bound
("understanding reached") invites **premature completion** - ending
the step before it is genuinely done, attention slipping to *being
done*. The visible steps still ahead supply that pull; the
criterion's clarity is the resistance. Defend in order: sharpen the
bound first, since that is local and cheap; only if it is
irreducibly fuzzy *and* you observe the rush, hide the later steps
by splitting the sequence. Hiding works only across a real context
boundary - a hand-off or a subagent dispatch. An inline call leaves
the later steps in context and clears nothing.

**Demand**: how much the criterion requires. "Every modified model
accounted for" forces thorough work where "produce a change list"
does not. Demand drives the **legwork** the agent does within the
work, latent in the wording rather than written as its own step, and
it is not step-bound: "every rule applied" binds a body of flat
reference just as "every step done" binds a sequence, which is how
an all-reference document still carries an exhaustiveness bar.

The strongest criteria are both checkable and exhaustive.

## When to split

Splitting one document into two spends one of the two loads, so
split only when the cut earns it. **By sequence**: split a run of
steps where the later ones tempt the agent to rush the one in front
of it - keeping them out of view drives more legwork on the current
task. Beware the reverse, that merging sequences exposes each step
to what follows and invites premature completion. **By invocation**
is skill-specific: see `writing-for-agents-mechanics.md`.

## Leading words

A **leading word** is a compact concept already living in the
model's pretraining that the agent thinks with while running the
document (*lesson*, *fog of war*, *tracer bullets*). Repeated as a
token, never as a sentence, it accumulates a distributed definition
and anchors a whole region of behaviour in the fewest tokens by
recruiting priors the model already holds. Coining your own works if
you define it clearly, but a made-up word recruits no priors: you
pay in definition tokens what a pretrained word gives free. Reach
for an existing word first.

It anchors twice. In the body, *execution*: the agent reaches for
the same behaviour every time the word appears, and inside flat
reference it focuses attention on a class of thing to look for. In a
pointer, *invocation*: when the same word lives in your prompts,
your docs and your code, the agent links that shared language to the
material and reaches it more reliably.

Hunt for refactors into leading words - a triad spelled out at three
sites, a pointer spending a sentence to gesture at one idea. Each is
a passage begging to collapse into a single token: "fast,
deterministic, low-overhead" becomes a *tight* loop; "a loop you
believe in" becomes *red*, turning a fuzzy gate into a binary
observable state. You win twice: fewer tokens, and a sharper hook
for the agent to hang its thinking on. Assume every document is
carrying restatements that leading words retire, and go find them.

**Negation** is the failure mode beside this lever. Steering by
prohibition drags the forbidden behaviour into context and makes it
*more* available, not less: *don't think of an elephant*, and the
elephant is all there is. The negation is a weak modifier the
strongly activated concept overruns, so the ban half-reads as an
instruction to do the thing. Prompt the **positive** - state the
target behaviour ("write one-line comments") so the banned one is
never spoken. A prohibition earns its place only as a hard guardrail
you cannot phrase positively, and even then it pairs with the
positive target, so attention lands on what to do.

## Pruning

- Keep each meaning in a **single source of truth**: one
  authoritative place, so changing the behaviour is a one-place
  edit. **Duplication** - the same meaning in more than one place -
  costs maintenance and tokens, and inflates a meaning's prominence
  on the ladder past its real rank. (The accidental inverse of a
  leading word, which repeats a token on purpose, never a meaning.)
- The **environment** is a source of truth too: `package.json`
  scripts, config files, the directory layout, `--help` output. A
  document restating it is a **cache**, a copy of a lookup, and
  earns its load only when the lookup is expensive. Cache what the
  agent cannot find by looking - the unwritten convention, the
  reason behind a choice, the gotcha no config confesses - and leave
  one-file, one-command lookups to the environment, where they
  cannot go stale.
- Check every line for **relevance**: does it still bear on what the
  document does? A line loses relevance by never bearing on the task
  (mere exposition, or a branch that should be disclosed) or by
  going stale as the behaviour it describes changes. Shorter
  documents are easier to keep relevant. Without a pruning
  discipline the default fate is **sediment**: stale layers that
  settle because adding feels safe and removing feels risky, until
  you have to core down through them to find what is still live.
- Hunt **no-ops** sentence by sentence: an instruction the model
  already obeys by default pays load to say nothing. The test - does
  it change behaviour against the default? - is model-relative, not
  reader-relative, so two people disagreeing about a no-op disagree
  about the default and settle it by running the document, not by
  debate. When a sentence fails, delete the whole sentence rather
  than trim words from it. The test also grades leading words: a
  word too weak to beat the default (*be thorough*, when the agent
  is already thorough-ish) is a no-op, and the fix is a stronger
  word (*relentless*), not a different technique.
