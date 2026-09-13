---
name: plan-create
description: "Create a plan for a new piece of work: interview the human until every ambiguity is resolved, draft plan.md and breakdown.md, run an AI design review loop over them, then get the human's inline review and sign-off. The approved plan is what plan-implement executes. Use when starting work that deserves a plan."
---

You are the orchestrator, and the executor of the design review loop.
Read `~/.config/plan-skills/PROTOCOL.md`, `ROLES.md` and `ARTIFACTS.md`
now, then follow them exactly.

Arguments (ask for whatever is missing rather than guessing):

- plan name.
- plan directory: default `docs/plans/<plan_name_slug>/`.
- reviewer profile: default `codex`; must be a different LLM from you.

Steps:

1. **Interview.** Resolve every ambiguity with AskUserQuestion before
   drafting anything: intent, pointers to existing context (the human
   often knows exactly where prior art lives - ask first, search later),
   scope in and out, constraints, dependencies, risks, deadlines,
   success criteria. Up to 4 questions per round, as many rounds as it
   takes; do not rush this. "Whatever you think is best" gets your
   recommendation and their explicit confirmation. Every decision lands
   in plan.md's Decisions table and is final.
2. **Draft** `plan.md` (status: draft) and `breakdown.md` per
   ARTIFACTS.md. Architecture level: what and why, not how.
3. **Design review loop** per PROTOCOL.md ("The design review"):
   `design-review` / `design-review-verify` templates, review file
   `plan_review.md`, plan status: in design review. You address items by
   editing the plan documents. Pause for the human after every reviewer
   round, as always.
4. **Human review.** When the loop closes, publish plan.md (and
   breakdown.md if useful) as a markdown artifact and hand the human the
   link. Fold their inline comments and feedback back into the files per
   ARTIFACTS.md.
5. **Sign-off.** On the human's explicit approval: flip plan.md status
   to `approved YYYY-MM-DD`, create worklog.md with the `[decision]`
   sign-off entry, republish the artifact. Point the human at
   `plan-implement` for the first item.

Never commit, push, or publish anywhere beyond the artifact above; the
human owns all of that.
