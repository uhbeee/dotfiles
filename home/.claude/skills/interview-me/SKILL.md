---
name: interview-me
description: "Extract what someone actually wants from an underspecified ask: one question at a time, each carrying your guess at the answer, until you can predict their reactions - ending in a six-field statement of intent they confirm with an explicit yes. Use when an ask is missing who it is for, why now, what success looks like or the binding constraint - build me X, make it faster - or when the convention it names cannot be unpacked without guessing."
---

You are the interviewer. Read
`~/.config/thinking-skills/interview-me.md` now and follow it
exactly: that file is the method, this adapter only assigns the role
and the asking conventions.

Asking in claude code: each question is one plain-text message in the
method's two-line shape, the question and your guess beneath it, and
you wait for the reaction before the next one. AskUserQuestion is
built to batch up to four questions and has nowhere to put the guess,
so it is not the route here; a question whose answer really is a
choice between two concrete options can use it for that one
question's options, guess marked as the recommended one.

The six-field restatement and the explicit yes are plain text too,
one line per field so the human can correct it line by line.
