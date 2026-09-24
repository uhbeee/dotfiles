---
name: plan-archive
description: "Move a finished plan's directory into an archive repo: verify the plan is terminal, stamp provenance, file it under <repo>/<plan>/, index it, and leave a one-line tombstone behind. Use when a plan's work is done and the plan should leave the working repo."
---

Archive the finished plan named in the user's request.

You are the orchestrator. Read `~/.config/plan-skills/ARTIFACTS.md`
("Archival") now, then follow it exactly. No reviewer seat is involved.

Asking in codex: its collaboration-mode rules come first, and a skill
does not override them. This skill writes files, so it runs in Default
mode, where `request_user_input` is for optional questions whose answer
would materially improve the work - one to three per call, prefer one,
every question carrying concrete options with your recommendation
marked - and an empty return means carry on with your best judgment
rather than ask again. Anything you actually need before you can
continue is not that kind of question: ask it as one concise plain-text
question and wait, never as options typed into a message, and never
route a permission ask through the tool. What no mode changes: the
answers below are the user's, so a missing one is asked for, never
assumed.

You need from the arguments or the user: the plan directory, and the
archive repo (default: the path in
`~/.config/dotfiles-local/plan-archive-root`; an explicit argument
overrides it; ask if neither exists).

The steps: verify the plan is terminal (every breakdown item
`done <commit>`, latest conformance fully closed; anything short is the
user's call, recorded first as a [decision] worklog entry); write
ARCHIVED.md into the plan directory per ARTIFACTS.md (source repo path
and remote, the items' commit range, created / approved / archived
dates, outcome against the plan's Intent, the plan-skills core
version - reporting what the worklog recorded and never better, so a
partial or unverified check is stamped as one); check the destination
`<archive repo>/<source repo name>/<plan_name_slug>/` - if it already
exists, stop and ask - a plain question, since you cannot continue
without the answer - as the archive is append-only and nothing is
copied, overwritten, or removed until the user resolves the collision -
then copy the directory there, verify the copy,
and append one index line to the archive's single index - the repo's
top-level README.md unless an index already exists elsewhere, which
then wins, and never a second one; append the
one-line tombstone to the source repo's docs/plans/ARCHIVE.md and
remove the plan directory; report both sides. The user owns the commit
in each repo; the move is not durable until both are committed.
