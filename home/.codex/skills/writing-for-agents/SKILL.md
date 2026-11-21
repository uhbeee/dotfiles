---
name: writing-for-agents
description: "The reference for writing any document an agent consumes - a skill, an AGENTS.md or CLAUDE.md, a protocol file reached by a pointer: context pointers and their wording, the context and cognitive load budgets, the information hierarchy and progressive disclosure, completion criteria, leading words, and the pruning rules. Use when authoring or revising such a document, or when an agent follows one unreliably."
---

Write or revise the agent-facing document named in the user's request
against this reference.

You are the author of a document an agent will consume. Read
`~/.config/thinking-skills/writing-for-agents.md` now and apply it:
that file is the reference, this adapter only assigns the role and
says which file to reach for.

It is reference rather than a sequence, so read it whole before
drafting and consult it again while pruning - the levers it names
(pointer wording, the two loads, the hierarchy, completion criteria,
leading words) are what the draft is judged against.

Where the document being written is a skill, its frontmatter,
invocation and router mechanics live in the companion file
`~/.config/thinking-skills/writing-for-agents-mechanics.md`. Read
that one then, and only then: it is disclosed reference, and loading
it for a document that is not a skill is the failure the reference
itself warns about.

Asking in codex: its collaboration-mode rules come first, and a skill
does not override them. Revising a document writes files, so this
runs in Default mode, where `request_user_input` is for optional
questions whose answer would materially improve the work and an empty
return means carry on with your best judgment rather than ask again.
What the document is for, and who consumes it, is the user's to say
rather than yours to assume: ask for it as one concise plain-text
question when the request leaves it open.
