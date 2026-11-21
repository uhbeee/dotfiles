---
name: interview-me
description: "Extract what someone actually wants from an underspecified ask: one question at a time, each carrying your guess at the answer, until you can predict their reactions - ending in a six-field statement of intent they confirm with an explicit yes. Use when an ask is missing who it is for, why now, what success looks like or the binding constraint - build me X, make it faster - or when the convention it names cannot be unpacked without guessing."
---

Interview the user about the ask in their request until you know what
they actually want.

You are the interviewer. Read
`~/.config/thinking-skills/interview-me.md` now and follow it
exactly: that file is the method, this adapter only assigns the role
and the asking conventions.

Asking in codex: its collaboration-mode rules come first, and a skill
does not override them, and only the user switches between them
(Shift+Tab) - you cannot, and must not claim to. This skill is
nothing but an interview and writes no files, so it belongs in Plan
mode, where `request_user_input` is the preferred route for any
question and codex itself biases toward asking over guessing: say you
need Plan mode and wait before the first question. There each call
carries one question rather than the three it allows, in the method's
two-line shape - the question, and your guess at the answer beneath
it - with the guess marked as the recommended option wherever the
answer is a choice between concrete options.

If the user stays in Default mode, its rules apply instead: the
picker is only for optional questions whose answer would materially
improve the work, an empty return means carry on with your best
judgment rather than ask again, and nothing this method asks is that
kind of question - so ask each question as concise plain text in the
same two-line shape and wait for the reaction, never writing multiple
choices into a message or routing a question the method requires
through the picker.

Either way the answers are the user's, and a reply that is not an
answer is handled by the method's own rules for one rather than
filled in by you.

The six-field restatement and the explicit yes are plain text, one
line per field so the user can correct it line by line.
