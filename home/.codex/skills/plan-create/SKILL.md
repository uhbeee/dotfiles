---
name: plan-create
description: "Create a plan for a new piece of work: interview the human until every ambiguity is resolved, draft plan.md and breakdown.md, run an AI design review loop over them, then get the human's inline review and sign-off. The approved plan is what plan-implement executes. Use when starting work that deserves a plan."
---

Create a plan for the work named in the user's request.

You are the orchestrator, and the executor of the design review loop,
defined in `~/.config/plan-skills/PROTOCOL.md`. Read that file,
`~/.config/plan-skills/ROLES.md` and `~/.config/plan-skills/ARTIFACTS.md`
now, then follow them exactly.

You need from the arguments or the user: the plan name, the plan
directory (default `docs/plans/<plan_name_slug>/`), and the
design-review reviewer profile (must be a different LLM from you, since
you edit the plan in that loop: default `claude`, per the protocol's
profile table). Ask for whatever is missing rather than guessing.

The steps: interview the user until every ambiguity is resolved (intent,
existing context pointers, scope in and out, constraints, dependencies,
risks, deadlines, success criteria) - up to 4 questions per round, as
many rounds as it takes, and "whatever you think is best" gets your
recommendation plus the user's explicit confirmation, never a silent
choice; the interview also asks which executor and
implementation-reviewer profiles the plan's items will use (defaults:
executor `claude`, reviewer `codex`; never the same LLM as each other),
recorded in the Decisions table where plan-implement and
plan-item-review read them; every decision lands in plan.md's Decisions
table and is final.
Then draft plan.md and breakdown.md per
ARTIFACTS.md at architecture level; run the design review loop per
PROTOCOL.md ("The design review") with the design-review templates and
review file plan_review.md, pausing for the user after every reviewer
round; then publish plan.md (and breakdown.md if useful) with
`plan-publish` for the user's own review, poll their annotations with
`plan-feedback`, and fold every annotation back into the files per
ARTIFACTS.md ("The review surface": an edit or a recorded
disagreement, disposition reported); on their explicit sign-off flip
plan.md's status to approved, create worklog.md with the [decision]
entry, and republish with `plan-publish` (drain pending feedback
first, per ARTIFACTS.md). Never commit, push, or publish on your own
initiative beyond the review surface above; the user owns those.
