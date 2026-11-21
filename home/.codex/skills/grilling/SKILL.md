---
name: grilling
description: "Stress-test a plan, a decision or an idea you already have: the subject is mapped as a design tree and every assumption behind it is put to you round by round, facts looked up rather than asked, until nothing is left silently assumed. Use when asked to grill it, poke holes in this, pressure-test or stress-test the thinking, or are we sure about this?"
---

Grill the plan, decision or idea named in the user's request.

You are the interviewer. Read `~/.config/thinking-skills/grilling.md`
now and follow it exactly: that file is the method, this adapter only
assigns the role and the asking conventions.

The subject is the user's to name - which plan, decision or idea is
on the table, and where it is written down - so ask for it rather
than guessing from the surrounding session.

Asking in codex: its collaboration-mode rules come first, and a skill
does not override them, and only the user switches between them
(Shift+Tab) - you cannot, and must not claim to. This skill is
nothing but an interview and writes no files, so it belongs in Plan
mode, where `request_user_input` is the preferred route for any
question and codex itself biases toward asking over guessing: say you
need Plan mode and wait before the first round. There each call
carries one to three questions, every question with concrete options
and your recommendation marked, so a frontier wider than three is
presented in chunks of at most three.

If the user stays in Default mode, its rules apply instead: the
picker is only for optional questions whose answer would materially
improve the work, an empty return means carry on with your best
judgment rather than ask again, and a frontier decision is never that
kind of question - so ask the frontier out one question at a time as
concise plain text and wait for each answer, never writing multiple
choices into a message or routing a required decision through the
picker. Say that this trades the method's round compression for the
mode, so the user can choose which they want.

A chunk, and a plain-text question just as much, is a presentation of
the live frontier rather than a fixed queue: recompute the frontier
after every answer, so frontier decisions still outstanding carry
into the next ask and an answer that invalidates a pending question
drops or replaces it instead of being asked anyway. The round ends
only once the frontier as recomputed is empty.

What no mode changes: the decisions are the user's. Answering one
yourself is the defect the method names, however reasonable the
answer.
