# Skill mechanics

The skill-specific branch of `writing-for-agents.md`: what changes
when the document being written is a skill. Everything else about
writing it is the universal reference in that file.

## Invocation

Two choices, trading the two loads.

A **model-invoked** skill keeps a `description`, so the agent can
fire it on its own and other skills can reach it. Typing its name
still works: model invocation *includes* user reach, and a
description only ever adds agent discovery, never removes the
human's. That description is the skill's top-level context pointer,
forced to stay loaded at all times - permanent context load in
exchange for discoverability. A model-invoked skill whose content is
all reference doubles as a home for shared reference, since another
skill can invoke it and the reference then lives in one place.
Mechanics: leave model invocation enabled, and write a model-facing
description carrying the trigger branches, under the pointer-writing
rules in `writing-for-agents.md`.

A **user-invoked** skill strips the description from the agent's
reach: only the human typing its name can invoke it, and no other
skill can. Zero context load, but it spends cognitive load - you are
the index that has to remember it exists. Mechanics: disable model
invocation in the frontmatter (`disable-model-invocation: true` in
claude code); the `description` turns human-facing, a one-line
summary with the trigger lists stripped.

Pick model invocation when the agent must reach the skill on its
own, or another skill must. A skill that only ever fires by hand is
user-invoked and pays no context load.

Shared reference that two user-invoked skills both need can live in
neither: with no descriptions, neither can fire the other. Push it
out to a plain file beside them - external reference that any skill
can point at.

## Splitting by invocation

The invocation cut of splitting, the sequence cut being in
`writing-for-agents.md`: split off a model-invoked skill when you
have a distinct leading word that should trigger it on its own - a
trigger word you actually use in your prompts - or when another
skill must reach it. The new always-loaded description is context
load you pay every turn, so that independent reach has to be worth
it.

## Router skills

When user-invoked skills multiply past what one human can remember,
the cure for that piled-up cognitive load is a **router skill**: one
user-invoked skill naming the others and when to reach for each, so
there is one skill to remember instead of many. It can only hint,
never fire them - user-invoked skills have no description, so
nothing but the human reaches them.
