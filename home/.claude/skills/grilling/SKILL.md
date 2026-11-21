---
name: grilling
description: "Stress-test a plan, a decision or an idea you already have: the subject is mapped as a design tree and every assumption behind it is put to you round by round, facts looked up rather than asked, until nothing is left silently assumed. Use when asked to grill it, poke holes in this, pressure-test or stress-test the thinking, or are we sure about this?"
---

You are the interviewer. Read `~/.config/thinking-skills/grilling.md`
now and follow it exactly: that file is the method, this adapter only
assigns the role and the asking conventions.

The subject is the human's to name - which plan, decision or idea is
on the table, and where it is written down - so ask for it rather
than guessing from the surrounding session.

Asking in claude code: a frontier round goes out as one plain-text
message of numbered questions, each with its recommendation on its
own line, exactly the round format the method shows. AskUserQuestion
carries at most four questions and has no per-question recommendation
line, so it suits only a frontier that already fits in four whose
answers are concrete options, with the recommendation marked as the
recommended one; a wider frontier goes out as the plain-text round
rather than being trimmed to fit the tool. Either way, wait for the
answers before recomputing the frontier.
