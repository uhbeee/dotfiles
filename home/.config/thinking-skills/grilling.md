# grilling

Interview the human relentlessly about a plan, a decision or an idea
until the two of you reach a shared understanding. Map the subject as
a **design tree**: every decision branches into the decisions that
hang off it, and the interview walks it branch by branch until no
assumption is left unstated.

This is the stress-test interview: the human already has something -
a plan, a decision, a direction - and wants holes poked in it. The
whole grill vocabulary belongs here (`grill me`, `poke holes in
this`, `stress-test my thinking`, `are we sure about this?`). An ask
too underspecified to have anything to stress-test yet belongs to
`interview-me`; this family's README draws the line.

## Rounds and the frontier

The **frontier** is every decision whose prerequisites are already
settled: the questions you can ask *now* without guessing at answers
you have not heard yet. Ask the whole frontier in one round, then
wait for the answers. Two questions never share a round if one
depends on the other; a question hinging on an answer still open
belongs to a later round, not this one.

Each round's answers reshape the tree: settled decisions push the
frontier outward and unblock the questions that depended on them.
Recompute the frontier from scratch and ask the next round. Thirteen
questions land in about three rounds rather than thirteen.

Format a round so it can be answered by number:

```
**Q1 - <short title>:** <question body; may run several paragraphs,
may offer explicit choices>

Recommendation: <the answer you would pick, and why>

**Q2 - <short title>:** <question body>

Recommendation: <the answer you would pick, and why>
```

Word each question so "yes" accepts your recommendation. When the
recommendation you arrive at argues against the question as drafted,
rewrite the question so the two agree, then ask it. A round where
"yes" means acceptance on one question and rejection on the next
cannot be answered by number, which is the whole point of the
format.

Where the CLI caps how many questions one ask may carry, present the
frontier in chunks no larger than that cap. A chunk is a presentation
of the live frontier, never a fixed queue: recompute the frontier
after every answered chunk, so an answer that invalidates a pending
question drops or replaces it instead of asking it anyway. Frontier
decisions still outstanding carry into the next chunk, and the round
ends only once the frontier as recomputed is empty.

## Facts are yours, decisions are theirs

Finding **facts** is your job, never the human's. When a frontier
question needs something the environment can settle - the
filesystem, a tool, the shape of existing code - dispatch a subagent
to find it instead of asking for it. Do not block on it: a running
exploration is an unsettled prerequisite, so only the questions
downstream of it wait, and the rest of the frontier gets asked now.

The **decisions** are the human's. Put each one to them and wait.
Answering your own decision question breaks the method however
reasonable the answer is: a grilling session you answered yourself
produced your opinion, not theirs.

## Ending

The session is done when the frontier is empty: every branch of the
tree visited, nothing left silently assumed. Then state the shared
understanding and wait for the human's confirmation before acting on
any of it. An empty frontier is not permission to start building.

Where what you agreed is a piece of work worth planning, offer
`plan-create` as the next step and stop there; the human picks.

## It is working if

- A round arrives as numbered questions, each with its
  recommendation on its own line, answerable whole by number.
- Nothing in a round needs another question in the same round
  answered first, and later rounds ask what earlier rounds could not.
- Facts get looked up - files read, a subagent dispatched - rather
  than asked, and research in flight stalls only the questions that
  depend on it.
- Question count stays high while round count stays low.
- The human pushes back somewhere. A session with no pushback in it
  is a session nobody needed.
- It stops at the empty frontier and asks for confirmation instead
  of starting the work.

## Limits

The frontier is judgment, not a graph computed from the tree: two
questions can land in one round and only afterwards turn out to
depend on each other. The guard is being told so, which reopens the
affected branch in the next round.

Some questions cannot be settled by talking at all - how something
should look, how an interaction should feel. Those need something to
react to. Say which question is one of those, propose building a
throwaway version to answer it, and wait: a prototype is work, so
the confirmation gate above covers it like any other. With the
human's go and something in front of them, the answer comes back in
one line and the interview resumes from the frontier where it
paused; without it, the question stays open and the rest of the
frontier carries on. Trying to talk one of these through is how a
session grows long while the scope grows with it.

A session running very long usually means the scope was too big.
Break the subject into pieces and grill the pieces.
