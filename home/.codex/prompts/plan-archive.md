Archive the finished plan named in the arguments:
$ARGUMENTS

You are the orchestrator. Read `~/.config/plan-skills/ARTIFACTS.md`
("Archival") now, then follow it exactly. No reviewer seat is involved.

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
version); check the destination
`<archive repo>/<source repo name>/<plan_name_slug>/` - if it already
exists, stop and ask, since the archive is append-only and nothing is
copied, overwritten, or removed until the user resolves the collision -
then copy the directory there, verify the copy,
and append one index line to the archive repo's README.md; append the
one-line tombstone to the source repo's docs/plans/ARCHIVE.md and
remove the plan directory; report both sides. The user owns the commit
in each repo; the move is not durable until both are committed.
