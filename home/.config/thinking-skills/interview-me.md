# interview-me

What someone asks for and what they actually want are different
things. They ask for "a dashboard" because that is what one asks
for, not because a dashboard solves their problem; they say "make it
faster" with no number to hit. This method closes that gap while
closing it is cheap - before any plan, spec or code exists.
Afterwards switching costs are real, and the human rationalizes the
wrong thing into a good-enough thing.

Reach for it when an ask is underspecified: missing **who** it is
for, **why** now, what **success** looks like, or the binding
**constraint**. Also when a request is conventional rather than
specific ("build me X") and the convention cannot be unpacked
without guessing; when two reasonable values are in tension
(simplicity against flexibility, cost against speed) and nobody
said which wins; and when you catch yourself filling in a
requirement you were never given. It is the wrong tool for an
unambiguous self-contained ask, a pure information request, a
mechanical operation, an explicit ask for speed over verification,
or confidence the ~95% stop rule already calls done.

**A live human is a prerequisite.** In a non-interactive
invocation - CI, a scheduled run, `claude -p`, an autonomous
loop - decline in the first turn and exit: report the
underspecified ask as a blocker and stop there. An interview nobody
is present to answer yields your own opinion dressed as theirs, and
stalls the run while it does it.

## The six steps

**1. Hypothesize, with a confidence number.** Before asking
anything, write your best read in one sentence plus an honest
confidence number from 0 to 100:

```
HYPOTHESIS: You want a way to answer "how are we doing?" in
standup, and "dashboard" was the convention that came to mind.
CONFIDENCE: ~30% - missing: who it is for, what "metrics" means
here, and what success looks like
```

The number forces honesty: one you cannot defend against the stop
rule is the wrong number. Below ~70%, name on the same line what is
unresolved - that is what tells the human which gap to close.

**2. Ask one question at a time, with your guess attached.**

```
Q: <one focused question>
GUESS: <your hypothesis for the answer, and the reasoning for it>
```

Wait for a reaction before the next question. One at a time because
a hypothesis buried in a list is one nobody reacts to, batches
invite skim-reading, the third question usually depends on the
first's answer, and careful-thinking energy is finite. A guess
attached because reacting to a wrong guess beats generating an
answer from scratch, and being visibly wrong puts your assumptions
on the table. The risk is a polite human agreeing to be agreeable:
stay visibly willing to be wrong, and now and then guess where you
expect pushback.

**3. Listen for want against should-want.** The dangerous answers
sound like what a thoughtful answer sounds like: best-practice talk
with no specifics ("scalable", "clean architecture"), deference to
convention ("the standard approach"), "I should probably...",
buzzwords standing in for an outcome. The probe for those: *if you
did not have to justify this to anyone, what would you actually
want?* It routinely outworks the five questions before it.

**4. Restate the intent in their words.** Once confidence is high,
write back what you now think they want - tight, their language, one
line per field so it can be corrected line by line:

```
- Outcome:      <one line>
- User:         <one line - who benefits>
- Why now:      <one line - what changed>
- Success:      <one line - how we know it worked>
- Constraint:   <one line - the binding limit>
- Out of scope: <one line - what this explicitly is not>

Yes / no / refine?
```

`Out of scope` stays in: half of all misalignment is silent
disagreement about what is not being built.

**5. Confirm on an explicit yes.** "Whatever you think is best" is
delegation, putting their confidence no higher than yours - re-ask
as a choice between two concrete options. "Sounds good" is
ambiguous - ask what they would refine. "Sure, let's go" is often a
polite exit - same follow-up. Silence and then "okay let's start"
means they gave up rather than converged - stop and ask what you
missed. Fold each correction in, restate, loop until the yes is
explicit.

**6. Terminal turn, then stop.** On an explicit yes: deliver the
confirmed statement of intent, offer the downstream paths, and end
the turn there - no tool calls, no downstream work in that turn.
Control goes back to the human to choose what is next. That
statement is the entire deliverable; specs, plans and task lists are
its downstream consumers. Offer to persist it to
`docs/intent/<topic>.md`, written only once they say yes, since the
document implies a yes they never gave. Where the next step is work
worth planning, `plan-create` is the pointer to offer.

## The stop rule: ~95% confidence

Confidence around 95% is not a vibe. It is this question answered
yes: *can I predict their reaction to the next three questions I
would ask?* If yes, stop asking and restate. If no, ask the next
question - a checkable test, not a feeling.

It has a floor as well as a ceiling. Several rounds with confidence
not visibly rising is information about the ask, not a reason to
keep going: something foundational is missing. Say exactly that -
"I have asked N questions and still cannot predict your reactions;
something foundational is missing, shall we step back?" - and step
back with them rather than interviewing on.

## Verification

- An explicit hypothesis with a confidence number in the first turn,
  and every number below ~70% carrying its one-line reason.
- One question per message, each with your guess attached.
- At least one "what would you actually want" probe against any
  sophistication- or convention-signaling answer.
- A concrete six-field restatement written back, confirmed by an
  explicit yes.
- At the stop point you could predict the next three reactions.
- The confirming turn called no tools and began no downstream work.
- The intent document was saved only after they asked for it.
- Any downstream handoff was framed in terms of the confirmed
  intent, not the original underspecified ask.
