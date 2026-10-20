#!/usr/bin/env bash
# Adapter parity check (herdr-seat-visibility plan, item 6).
#
# PROTOCOL.md's opening invariant: "the protocol holds the behavior; the
# adapters stay thin ... a step, gate, or lifecycle that exists in one
# adapter and not its counterpart is a defect in the one that lacks it,
# whichever way round". This test is that invariant made mechanical over
# the authored adapters in home/.claude/skills/plan-* and
# home/.codex/skills/plan-*.
#
# Six layers. The first three are differential - the question is never
# "does this adapter say X" but "do both say it, or neither" - and the
# last three keep the third honest:
#
#   1. Shape: the same plan-* skill set on both sides, each with a
#      SKILL.md whose frontmatter name matches its directory and whose
#      description is byte-identical to its counterpart's, and each
#      linked for both CLIs by modules/home/common/plan-skills.nix - an
#      adapter nobody links is an adapter nobody has.
#   2. Vocabulary: a lexical token set per file - herdr and git command
#      phrases, long flags, worklog entry kinds, document basenames,
#      snake_case identifiers, plan-* skill names, ROLES.md template
#      names, CamelCase tool names - compared pairwise. A step that
#      names a command, flag, file, template or entry kind cannot be
#      dropped from one adapter without dropping a token. Needs no
#      per-skill expectations: tokens are extracted from whatever the
#      files say.
#   3. Gates and named steps: a registry of instructions matched as
#      verb phrases rather than bare names ("invoke the plan-item-review
#      skill", not "plan-item-review"), which is what separates an
#      executable step from an incidental mention. Covers both the
#      enumerated steps and the prose-only rules that carry no literal
#      at all, each with alternates spanning both adapters' wording,
#      asserted present on both sides or neither.
#   4. Step coverage: every enumerated step of every claude adapter
#      must be matched by at least one registry entry, so a step
#      nothing carries across cannot exist. Without this layer the
#      registry silently fails to grow with the skills - how the
#      "Review gate" step of plan-implement escaped round 1 of this
#      check. Coverage is a floor, not a ceiling: one entry per step
#      satisfies it, which is why layer 5 exists.
#   5. Action/condition links: a registry entry naming what a step DOES
#      is linked to the entry naming the prerequisite that permits it,
#      and wherever the action is stated the condition must be stated
#      in the same body, each side checked independently. This is the
#      one non-differential layer, and deliberately: a prerequisite
#      both adapters lose stays symmetric, so parity cannot see it -
#      how dropping "On the human's explicit approval:" from the
#      sign-off step escaped round 2.
#   6. The unpoliced remainder: every clause of every adapter with the
#      spans its registry entries match elided, and whatever is left
#      frozen in tests/adapter-parity-unpoliced.txt. Any change to
#      that remainder fails until the rule is registered as a gate or
#      the change is deliberately accepted (UPDATE_UNPOLICED=1
#      regenerates the snapshot). Layers 1 to 5 only see what the
#      registry names; four review rounds found the same shape of miss
#      in what it did not, the fourth inside a clause whose other half
#      a gate matched - which is why the remainder is computed per
#      span and not per clause. This layer does not close that class -
#      the long comment above layer 6 gives the two measurements
#      showing it cannot be closed by matching harder - but it makes
#      the uncovered text enumerated, shrinking as the registry grows,
#      and unchangeable in silence.
#
# Matching runs over the instruction body only, never the frontmatter:
# the description repeats names the body also uses ("gate it through
# plan-item-review"), so including it lets the description stand in for
# a step deleted from the body. Layer 1 compares the description
# byte-for-byte, so nothing goes unchecked.
#
# Text is normalized before matching - backticks and bold markers
# stripped, newlines collapsed to single spaces - because the two
# adapters wrap and emphasize differently and a raw-line grep reports
# "workspace status\ntoken" as absent (the false-positive mode the item
# 5 validation ran into).
#
# Legitimate per-orchestrator differences are a registry, not a
# tolerance: every exemption names the token, the side that may carry
# it, and why, and an exemption that no longer matches anything fails
# as stale. PROTOCOL.md allows exactly this class - "CLI-specific how,
# not what".
#
# The negative controls at the end mutate throwaway copies of the tree
# - a command removed, a skill deleted, a description edited, a
# prose-only gate deleted, a flag dropped, a whole named step deleted,
# a gate's prerequisite removed from either side and then from both at
# once, a clause deleted from and added to the unpoliced region, a step
# no registry entry covers, one CLI's link dropped from the nix
# module - and assert the engine reports each one, so the check
# is proven to fail on divergence by running, not by inspection. A
# control only means something from a clean baseline, so each one is
# skipped (printed, never silently) when the layer it exercises already
# has findings on the real tree: otherwise a control whose fixture
# touches the same clause as a real divergence reads as a broken
# engine.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail=0
ok() { echo "ok - $1"; }
bad() { echo "not ok - $1"; fail=1; }

CLAUDE_REL="home/.claude/skills"
CODEX_REL="home/.codex/skills"
ROLES="$ROOT/home/.config/plan-skills/ROLES.md"
WIRING="$ROOT/modules/home/common/plan-skills.nix"

# --- preflight: an inspection that cannot run never reports clean ------------

for required in "$ROOT/$CLAUDE_REL" "$ROOT/$CODEX_REL" "$ROLES" "$WIRING"; do
  if [ ! -e "$required" ]; then
    echo "not ok - cannot compare adapters: $required is missing"
    exit 1
  fi
done

# --- normalization -----------------------------------------------------------

# One line, no backticks, no bold markers, no runs of whitespace. Case
# is preserved: the CamelCase class needs it; gate matching lowercases
# itself. Backticks and `**` go because they are formatting, not
# content: one adapter writes a step name as "**Report** both sides"
# and the other as "report both sides", and that is not divergence.
flatten() { tr -d '`' | sed 's/\*\*//g' | tr '\n\t' '  ' | tr -s ' '; }

# The normalized instruction body only: the YAML frontmatter is
# dropped first. Every matching layer uses this rather than norm,
# because the frontmatter description repeats names the body also uses
# ("gate it through plan-item-review"), and a whole-file match lets
# that description stand in for a deleted step. The description is not
# unchecked - the shape layer compares it byte-for-byte - so dropping
# it here only removes a mask.
body() {
  awk 'NR == 1 && $0 == "---" { fm = 1; next }
       fm && $0 == "---" { fm = 0; next }
       !fm' "$1"
}
norm_body() { body "$1" | flatten; }

# --- layer 2: the lexical vocabulary ----------------------------------------

# Words that follow "git" or a herdr noun in prose rather than as a
# subcommand. Only used to trim command phrases.
STOP=" the a an to in on at of and or with as that this these those "
STOP="$STOP is are was it its by for from so then than rather never always "
STOP="$STOP when while where which who whose what if unless until before "
STOP="$STOP after both each every all any no not none nothing only also do "
STOP="$STOP does did can could may might must shall should will would you "
STOP="$STOP your yours we our they them their be been being have has had "
STOP="$STOP here there now once per via over under up down out off into "
STOP="$STOP onto about above below between during through against among "
STOP="$STOP within without because since though although however instead "
STOP="$STOP still just like "

# The herdr surface the protocol drives. Noun x verb rather than free
# text, so "the workspace step" and "an agent other than yourself" are
# prose, not commands. A herdr prefix is optional: the adapters write
# both "herdr worktree open" and a bare "worktree open".
HERDR_NOUNS='worktree|workspace|pane|agent|notification|integration'
HERDR_VERBS='create|open|list|remove|close|split|move|start|prompt|read|get|send-keys|report-metadata|show|status'

# Role template names come from ROLES.md's own headings, so a renamed
# or added template is covered without editing this file.
template_names() {
  grep -oE '^## [a-z][a-z-]*$' "$ROLES" | sed 's/^## //' | sort -u
}

tokens() { # tokens <file>
  local f=$1 n t
  n=$(norm_body "$f")
  {
    # Command phrases.
    grep -oE "(^|[^a-z-])(herdr )?($HERDR_NOUNS) ($HERDR_VERBS)([^a-z-]|$)" <<<"$n" |
      sed -E 's/^[^a-z]*//; s/[^a-z-]*$//; s/^herdr //' | sed 's/^/cli:/'
    grep -oE 'git [a-z][a-z0-9-]*( [a-z][a-z0-9-]*)?' <<<"$n" |
      while read -r b w1 w2; do
        case "$STOP" in *" $w1 "*) continue ;; esac
        case "$STOP" in *" $w2 "*) w2="" ;; esac
        echo "cli:$b $w1${w2:+ $w2}"
      done
    # Long flags.
    grep -oE -- '--[a-z][a-z0-9-]*' <<<"$n" | sed 's/^/flag:/'
    # Worklog entry kinds: [session], [decision], [handoff], ...
    grep -oE '\[[a-z][a-z-]*\]' <<<"$n" | sed 's/^/entry:/'
    # Documents, by basename: the two adapters cite the same file with
    # different path depth ("ROLES.md" against the full ~/.config path).
    grep -oE '[A-Za-z0-9_./~-]*\.(md|sh|nix|json)' <<<"$n" | sed 's#.*/##' | sed 's/^/doc:/'
    # herdr states and error codes, CLI field names, slug placeholders.
    grep -oE '[a-z][a-z0-9]*(_[a-z0-9]+)+' <<<"$n" | sed 's/^/id:/'
    # Sibling skills the adapter hands off to.
    grep -oE 'plan-[a-z][a-z-]*' <<<"$n" | sed 's/^/skill:/'
    # Role templates, from ROLES.md.
    while read -r t; do
      [ -n "$t" ] || continue
      grep -qE "(^|[^a-z-])$t([^a-z-]|$)" <<<"$n" && echo "tmpl:$t"
    done < <(template_names)
    # CLI-specific tool names (AskUserQuestion and friends).
    grep -oE '[A-Z][a-z]+[A-Z][A-Za-z]+' <<<"$n" | sed 's/^/camel:/'
  } | sort -u
}

# --- layer 2: exemptions ----------------------------------------------------

# <skill>|<side>|<token>|<why>. <skill> is a skill name or * for all.
# Only the named side may carry the token; the other side lacking it is
# not a divergence. Anything else one-sided is a failure.
exemptions() {
  cat <<'EOF'
*|codex|id:request_user_input|codex asks through its collaboration-mode picker; the claude adapters ask with their own question tool. PROTOCOL.md admits exactly this: CLI-specific how, not what.
*|claude|camel:AskUserQuestion|the claude question tool, named only where it exists; codex's counterpart is request_user_input above.
EOF
}

exempt_reason() { # exempt_reason <skill> <side> <token>
  exemptions | awk -F'|' -v s="$1" -v side="$2" -v t="$3" \
    '($1==s || $1=="*") && $2==side && $3==t { print $4; found=1 } END { exit !found }'
}

# --- layer 3: gates with no literal -----------------------------------------

# <key>|<ERE, matched case-insensitively against the normalized text>.
# Alternates span both adapters' wording, including codex's "user" for
# claude's "human". A key present on one side and absent on the other
# is a divergence; absent on both is simply a gate that skill does not
# carry.
gates() {
  cat <<'EOF'
ask-never-guess|rather than guess|ask rather than guess|asked for, never assumed
implements-nothing|implements? nothing
different-llm|same llm
default-reviewer|default (claude|codex)|fallbacks? executor
approval-gate|status is not approved|unless plan.md's status is approved
blocking-edges|blocking edges are all satisfied
classic-flow-unchanged|classic single-checkout flow
validation-red-cap|three validation-red resumes
verify-round-cap|three verify rounds
human-validation-lines|human: validation lines
pause-every-round|after every reviewer round
no-closure-by-orchestrator|close an item|closes? an item
no-editing-reviewer-text|reviewer'?s? text
template-only-prompts|filled template only|nothing else in the prompt|template filled
case-goes-in-review-file|case for an item goes into
fresh-session|fresh session
never-commit-unbidden|never commit, push
merge-separate-word|separate word
headless-temp-log|headless[,:] (capture|its stdout|that is)
hosted-pane-transcript|pane transcript is the record
settled-state-wait|settled-state wait
no-tailing|without tailing it
session-boundary-entry|boundary entry|\[session\] boundary
no-backdated-ids|back-dat
blocked-and-abnormal|blocked and abnormal
own-seat-at-first-boundary|your own seat and profile
validation-where-work-is|plan checkout
default-branch-resolution|refs/heads
stale-checkout-path|recorded checkout_path
no-second-workspace|second workspace
workspace-status-token|status token
teardown-gate|teardown gate
abandonment-is-human|abandon
every-item-done-commit|every item done
archive-append-only|append-only
archive-single-index|single index|never a second|never start a second
terminal-gate|terminal gate
architecture-level|architecture level
decisions-final|table and is final|table is final|that table is final
interview-rounds|as many rounds as it takes
adapters-named-in-items|every adapter it touches|adapter it touches
reads-worklog-tail|tail of worklog.md
handoff-baton|previous session's baton
review-gate-invokes-item-review|(invoke|run) the plan-item-review skill
sync-after-closure|(invoke|run|then) the plan-sync skill
publish-for-human-review|poll their annotations
fold-annotations|fold every annotation
signoff-flips-status|flip plan.md'?s? status to approved
signoff-creates-worklog|create worklog.md with
drain-pending-feedback|drain pending feedback
sync-answers-open-questions|open questions
questions-change-takes-decision|rewording the questions
raise-not-edit-decisions|contradict a Decision
worklog-records-deviations|entries for deviations
done-entry-needs-commit|only when the commit exists
republish-with-plan-publish|republish the plan with plan-publish
archive-terminal-gate|plan is terminal
archive-stamps-archived-md|ARCHIVED.md into the plan directory
archive-reports-no-better|never better
archive-tombstone|one-line (pointer|tombstone)
archive-removes-plan-dir|remove the plan directory
archive-reports-both-sides|report both sides
archive-commit-per-repo|commit in each repo
archive-durability|not durable until both
signoff-needs-explicit-approval|explicit approval|explicit sign-off
explicit-go-required|explicit go
go-is-per-action|go for one is not a go for the next
merge-after-seen|after they have seen it
review-gate-after-exit-criteria|exit criteria pass
boundary-before-spawn|immediately before
teardown-needs-settled-seats|seat has settled|seats settled
teardown-needs-clean-checkout|checkout is clean
successor-refused-without-commit|refuses the successor
validation-after-every-implemented|after every implemented exit
fresh-spawn-only-if-lost|session is lost or the profile changed
never-resume-reviewer-id|reviewer'?s? id entry|reviewer ids live
recommendation-plus-confirmation|explicit confirmation
annotation-disposition|disposition reported
archive-collision-stops|already exists, stop and ask
archive-verify-copy-first|verify the copy
archive-override-recorded-first|recorded first as a
human-lines-never-to-executor|never to the executor
pause-before-acting|before acting on it
never-origin-ref|origin/<name>|remote-tracking ref
confirm-item-with-human|confirm[^.]{0,80}(human|user)
archive-items-done|every breakdown item done
archive-conformance-closed|conformance( file)? fully closed
archive-short-goes-to-human|anything short
archive-stamp-partial|partial or unverified
archive-destination-path|<archive repo>/<source repo name>
archive-nothing-until-resolved|until the (human|user) resolves
archive-existing-index-wins|exists elsewhere, which then wins
conformance-after-all-items-closed|all items (are )?closed?
blocking-edge-needs-commit-on-branch|commit is on the work branch
open-workspace-not-proof|not proof it still points
first-item-nothing-to-recover|nothing to recover
plan-docs-in-primary-checkout|stay in the primary checkout
outside-herdr-plain-branch|plain branch as before
classify-exit-per-protocol|classify the exit
validation-evidence-either-way|worklog entry (either way|whether it passed or not)
handoff-at-stopping-point|natural stopping point
workspace-survives-pause|survives the pause
pr-left-for-them|for them to review
nothing-from-session-in-prompt|nothing from this session|with your session context
verify-rounds-resume-reviewer|verify rounds resume
standalone-review-needs-worklog|standalone reviews
review-file-stays-in-plan-dir|stay in the plan directory
reviewer-gets-full-session-record|same \[session\] record|full \[session\] pair
claude-p-id-at-exit|arrives at exit|ids only at exit
repo-is-the-record|repo is the record
reviewed-until-commit|reviewed (while|until)
commit-identified-with-human|identified with the (human|user)
deviation-noted-with-status-header|status header line
recording-answer-is-your-work|recording an answer is your work
reviewed-gets-handoff|as a \[handoff\]|\[handoff\] instead
short-of-both-leave-open|leave the workspace open
mid-plan-sync-normal|normal outcome of a mid-plan sync
human-owns-doc-commit|owns the commit of the doc updates|owns every commit
report-findings-and-path|findings and the file path|findings to the (human|user) with the file path
findings-become-new-round|new plan-item-review round
teardown-needs-pane-closed|pane is closed|panes closed
archive-copies-directory|copy the (plan )?directory there
archive-one-index-line|one index line
one-reviewer-invocation|one reviewer invocation
refusal-goes-to-human|refusal goes to the
interview-covers-scope|scope in and out
EOF
}

# --- the matcher -------------------------------------------------------------

# The registry is matched in one perl process per file rather than one
# grep per pattern: with 100+ entries, 6 pairs and a dozen engine runs
# per suite, per-pattern greps cost tens of thousands of processes and
# minutes of wall clock. Perl is already a dependency here (the
# negative controls mutate with it) and takes the patterns verbatim,
# case-insensitively, exactly as grep -iE did.
GATES_FILE=$(mktemp "${TMPDIR:-/tmp}/adapter-parity-gates.XXXXXX")
trap 'rm -f "$GATES_FILE"' EXIT
gates > "$GATES_FILE"

# Which registry keys match a file's instruction body, one per line.
gate_hits() { # gate_hits <SKILL.md>
  norm_body "$1" | perl -e '
    my $pf = shift;
    open(my $fh, "<", $pf) or die "gates: $!";
    my @pats;
    while (<$fh>) { chomp; next unless length; my ($k, $p) = split(/\|/, $_, 2); push @pats, [$k, qr/$p/i] }
    local $/; my $text = <STDIN>;
    for my $e (@pats) { print "$e->[0]\n" if $text =~ $e->[1] }
  ' "$GATES_FILE"
}

# For each line of stdin, what is left after every span a registry
# entry matches is elided. A line fully accounted for prints nothing;
# a line the registry only partly covers prints its remainder with
# "[gate]" where the covered spans were. This is the honest complement
# of the registry: clause-level "did anything match" hid an
# unregistered instruction sharing a clause with a registered one (the
# teardown prerequisite "and its pane is closed", audit 3).
residue_lines() {
  perl -e '
    my $pf = shift;
    open(my $fh, "<", $pf) or die "gates: $!";
    my @pats;
    while (<$fh>) { chomp; next unless length; my (undef, $p) = split(/\|/, $_, 2); push @pats, qr/$p/i }
    while (my $l = <STDIN>) {
      chomp $l; next unless length $l;
      my $r = $l;
      for my $p (@pats) { $r =~ s/$p/ [gate] /g }
      $r =~ s/(?:\s*\[gate\]\s*)+/ [gate] /g;
      $r =~ s/^\s+//; $r =~ s/\s+$//;
      my $bare = $r; $bare =~ s/\[gate\]//g; $bare =~ s/[^A-Za-z0-9]//g;
      next unless length $bare;
      print "$r\n";
    }
  ' "$GATES_FILE"
}

# The lines of stdin that no registry entry matches.
unmatched_lines() {
  perl -e '
    my $pf = shift;
    open(my $fh, "<", $pf) or die "gates: $!";
    my @pats;
    while (<$fh>) { chomp; next unless length; my (undef, $p) = split(/\|/, $_, 2); push @pats, qr/$p/i }
    LINE: while (my $l = <STDIN>) {
      chomp $l; next unless length $l;
      for my $p (@pats) { next LINE if $l =~ $p }
      print "$l\n";
    }
  ' "$GATES_FILE"
}

# --- layer 4: every named step is covered by the registry --------------------

# The executable instruction units of a claude adapter: numbered steps,
# plus the top-level bullets of its "Steps:" or "Non-negotiables"
# section. Argument lists above that heading are inputs, not steps, and
# are left out - the shape and vocabulary layers already cover them.
# Continuation lines (including indented fenced blocks) fold into their
# unit; an unindented paragraph ends one.
steps_of() { # steps_of <SKILL.md>
  body "$1" |
    awk '
      function flush() {
        if (cur != "") {
          gsub(/[ \t]+/, " ", cur); sub(/^ +/, "", cur); sub(/ +$/, "", cur)
          if (cur != "") print cur
        }
        cur = ""
      }
      /^Steps:/ || /^Non-negotiables/ { started = 1; flush(); next }
      /^[0-9]+\. / { flush(); cur = $0; next }
      started && /^- / { flush(); cur = $0; next }
      /^[^ \t]/ { flush(); next }
      { if (cur != "") cur = cur " " $0 }
      END { flush() }
    ' |
    tr -d '`' | sed 's/\*\*//g; s/  */ /g'
}

# A step no gate matches is a step the registry does not carry to the
# other adapter: delete it from one side and the vocabulary layer may
# still find its names elsewhere in the file. That is exactly how the
# "Review gate" step of plan-implement escaped round 1 of this check,
# so coverage is asserted rather than assumed. The audit runs over the
# claude adapters because they are the ones written as enumerated
# steps; the codex adapters are one running paragraph, and what carries
# each step to them is the gate's own both-sides-or-neither comparison
# above.
# Prints one line per uncovered step; silence means full coverage. The
# trailing summary line is prefixed "counts:" so callers can report it
# separately from the findings.
step_coverage_report() { # step_coverage_report <claude skills root>
  local croot=$1 sk unit units uncovered total=0 prose=0
  for sk in $( (cd "$croot" && ls -d plan-*) ); do
    units=$(steps_of "$croot/$sk/SKILL.md")
    if [ -z "$units" ]; then
      # Written as prose, with no enumerated steps: at least assert the
      # registry reaches it at all.
      if [ -n "$(gate_hits "$croot/$sk/SKILL.md")" ]; then
        prose=$((prose + 1))
      else
        echo "unregistered skill: $sk has no enumerated steps and no gate matches its body"
      fi
      continue
    fi
    total=$((total + $(grep -c . <<<"$units")))
    uncovered=$(unmatched_lines <<<"$units")
    while IFS= read -r unit; do
      [ -n "$unit" ] || continue
      echo "uncovered step: $sk: \"$(cut -c1-56 <<<"$unit")...\" matches no gate - add one, or deleting it from one adapter goes unnoticed"
    done <<<"$uncovered"
  done
  echo "counts: $total steps; $prose skill(s) written as prose, reached by gate"
}

# --- layer 5: an action never stands without the condition permitting it ----

# <action key>|<condition key>. Parity alone cannot see a condition
# that both adapters lose, and a gate that names only what a step DOES
# passes while the prerequisite that permits it is deleted - the
# conformance finding of 2026-10-19, where dropping "On the human's
# explicit approval:" from claude's sign-off left the suite green
# because `signoff-flips-status` matched the action either way. These
# links are the audit of that class, kept as data: wherever the action
# matches a body, the condition must match the same body, on both
# sides independently.
requires() {
  cat <<'EOF'
signoff-flips-status|signoff-needs-explicit-approval
signoff-creates-worklog|signoff-needs-explicit-approval
review-gate-invokes-item-review|review-gate-after-exit-criteria
sync-after-closure|review-gate-after-exit-criteria
session-boundary-entry|boundary-before-spawn
merge-separate-word|merge-after-seen
republish-with-plan-publish|drain-pending-feedback
teardown-gate|every-item-done-commit
teardown-gate|teardown-needs-settled-seats
teardown-gate|teardown-needs-clean-checkout
fold-annotations|annotation-disposition
archive-stamps-archived-md|archive-terminal-gate
archive-single-index|archive-collision-stops
archive-tombstone|archive-verify-copy-first
archive-removes-plan-dir|archive-verify-copy-first
archive-terminal-gate|archive-items-done
archive-terminal-gate|archive-conformance-closed
archive-terminal-gate|archive-short-goes-to-human
archive-stamps-archived-md|archive-reports-no-better
archive-append-only|archive-nothing-until-resolved
archive-single-index|archive-existing-index-wins
terminal-gate|conformance-after-all-items-closed
blocking-edges|blocking-edge-needs-commit-on-branch
default-branch-resolution|never-origin-ref
teardown-gate|teardown-needs-pane-closed
archive-single-index|archive-one-index-line
EOF
}

gate_is_key() { # gate_is_key <key>
  cut -d'|' -f1 "$GATES_FILE" | grep -qxF "$1"
}

# Prints one line per action standing without its condition, and one
# per broken link; silence means every linked condition holds.
condition_report() { # condition_report <claude skills root> <codex skills root>
  local croot=$1 xroot=$2 sk side root action cond hits
  while IFS='|' read -r action cond; do
    [ -n "${action:-}" ] || continue
    if ! gate_is_key "$action" || ! gate_is_key "$cond"; then
      echo "broken link: $action requires $cond, but one of them is not a registry key"
    fi
  done < <(requires)
  for sk in $( (cd "$croot" && ls -d plan-*) ); do
    for side in claude codex; do
      [ "$side" = claude ] && root=$croot || root=$xroot
      [ -f "$root/$sk/SKILL.md" ] || continue
      hits=$(gate_hits "$root/$sk/SKILL.md")
      while IFS='|' read -r action cond; do
        [ -n "${action:-}" ] || continue
        grep -qxF "$action" <<<"$hits" || continue
        grep -qxF "$cond" <<<"$hits" ||
          echo "action without its condition: $sk ($side): '$action' is stated but '$cond' is not"
      done < <(requires)
    done
  done
}

# --- layer 6: the region no registry entry covers, snapshotted ---------------

# Everything above compares what the registry knows about. Three
# rounds of review found the same shape of miss - a check matching a
# surface while the meaning behind it disappeared - and each fix added
# patterns, which closes instances rather than the class: whatever no
# entry names is invisible, and nothing told anyone which text that
# was.
#
# Two measurements say the class cannot be closed by matching harder.
# A complete word-level differential between the two adapters reports
# 218 one-sided content terms on a correct tree (wording, not
# substance: "invoke" against "run", "plainly" against "plain"), so
# suppressing it needs an exemption list bigger than this registry,
# and an exemption blinds the check permanently where a missing entry
# only fails to catch one change. Clause-level pattern coverage of the
# same text would need an entry for every one of the ~160 clauses no
# entry matches today, at which point the registry is an exact-text
# diff with a translation table.
#
# So this layer does not try to understand the remainder - it freezes
# it. Each clause of each adapter body has the spans its registry
# entries match elided, and whatever text survives that elision is
# recorded in a snapshot file beside this test. Any change to it, in
# either direction, fails: text appearing there must be registered or
# deliberately accepted, and text vanishing from there has to be
# confirmed against the counterpart adapter. The remainder is computed
# per span rather than per clause because the first version of this
# layer asked only whether a clause matched anything, and an
# unregistered instruction sharing a clause with a registered one -
# the teardown prerequisite "and its pane is closed" - was therefore
# invisible to the registry and to the snapshot at once. What this
# still cannot do is judge the change for you: it forces a look, and a
# careless regeneration will accept a one-sided edit. That is the
# honest end of a text-level check over two deliberately
# differently-worded documents.
#
# Regenerate after a deliberate change:
#   UPDATE_UNPOLICED=1 bash tests/adapter-parity.test.sh
UNPOLICED_SNAPSHOT="$ROOT/tests/adapter-parity-unpoliced.txt"

# Clauses are split on sentence ends and on ; and : because a named
# gate often sits in a clause rather than a sentence of its own - the
# archive terminal gate's "every breakdown item done <commit>" is the
# middle of one sentence, which is how its deletion stayed invisible.
unpoliced_clauses() { # unpoliced_clauses <claude skills root> <codex skills root>
  local croot=$1 xroot=$2 sk side root
  for sk in $( (cd "$croot" && ls -d plan-*) ); do
    for side in claude codex; do
      [ "$side" = claude ] && root=$croot || root=$xroot
      [ -f "$root/$sk/SKILL.md" ] || continue
      norm_body "$root/$sk/SKILL.md" |
        perl -pe 's/(?:[;:]|\. )/\n/g' |
        awk 'NF >= 3 { sub(/^ +/, ""); sub(/ +$/, ""); print }' |
        residue_lines |
        sed "s|^|$side/$sk: |"
    done
  done
}

# Prints one line per change to the unpoliced region.
unpoliced_report() { # unpoliced_report <claude skills root> <codex skills root>
  local current
  current=$(unpoliced_clauses "$1" "$2" | sort)
  if [ ! -f "$UNPOLICED_SNAPSHOT" ]; then
    echo "unpoliced snapshot missing: $UNPOLICED_SNAPSHOT - regenerate with UPDATE_UNPOLICED=1"
    return
  fi
  comm -13 <(sort "$UNPOLICED_SNAPSHOT") <(echo "$current") |
    sed 's/^/unpoliced text appeared: /' | grep . || true
  comm -23 <(sort "$UNPOLICED_SNAPSHOT") <(echo "$current") |
    sed 's/^/unpoliced text vanished: /' | grep . || true
}

# --- the engine --------------------------------------------------------------

# Prints one line per divergence found between two adapter trees.
# Silence means parity. Never exits nonzero: callers count lines, which
# is what lets the negative controls assert a failure is reported.
parity_report() { # parity_report <claude skills root> <codex skills root>
  local croot=$1 xroot=$2 s f cfile xfile cdesc xdesc side tok why
  local cskills xskills

  cskills=$( (cd "$croot" 2>/dev/null && ls -d plan-* 2>/dev/null) | sort )
  xskills=$( (cd "$xroot" 2>/dev/null && ls -d plan-* 2>/dev/null) | sort )
  if [ "$cskills" != "$xskills" ]; then
    comm -23 <(echo "$cskills") <(echo "$xskills") |
      sed 's/^/shape: skill present for claude and missing for codex: /' | grep . || true
    comm -13 <(echo "$cskills") <(echo "$xskills") |
      sed 's/^/shape: skill present for codex and missing for claude: /' | grep . || true
  fi

  for s in $(comm -12 <(echo "$cskills") <(echo "$xskills")); do
    cfile="$croot/$s/SKILL.md"
    xfile="$xroot/$s/SKILL.md"
    if [ ! -f "$cfile" ] || [ ! -f "$xfile" ]; then
      echo "shape: $s: SKILL.md missing on one side"
      continue
    fi
    for side in claude codex; do
      [ "$side" = claude ] && f=$cfile || f=$xfile
      if ! grep -qxF "name: $s" "$f"; then
        echo "shape: $s ($side): frontmatter name does not match the directory"
      fi
    done
    cdesc=$(grep -m1 '^description:' "$cfile")
    xdesc=$(grep -m1 '^description:' "$xfile")
    if [ "$cdesc" != "$xdesc" ]; then
      echo "shape: $s: descriptions differ (claude: $cdesc / codex: $xdesc)"
    fi

    # Layer 2. Extract once per side; comm reads both sets from there.
    local ctok xtok
    ctok=$(tokens "$cfile"); xtok=$(tokens "$xfile")
    while read -r tok; do
      [ -n "$tok" ] || continue
      if why=$(exempt_reason "$s" codex "$tok"); then continue; fi
      echo "vocabulary: $s: codex carries $tok, claude does not"
    done < <(comm -13 <(echo "$ctok") <(echo "$xtok"))
    while read -r tok; do
      [ -n "$tok" ] || continue
      if why=$(exempt_reason "$s" claude "$tok"); then continue; fi
      echo "vocabulary: $s: claude carries $tok, codex does not"
    done < <(comm -23 <(echo "$ctok") <(echo "$xtok"))

    # Layer 3. One matcher pass per side, then a set comparison.
    local chits xhits
    chits=$(gate_hits "$cfile"); xhits=$(gate_hits "$xfile")
    comm -23 <(sort <<<"$chits") <(sort <<<"$xhits") |
      sed "s/^/gate: $s: claude covers '/; s/$/', codex does not/" | grep . || true
    comm -13 <(sort <<<"$chits") <(sort <<<"$xhits") |
      sed "s/^/gate: $s: codex covers '/; s/$/', claude does not/" | grep . || true
  done
}


# --- run 1: the real tree ----------------------------------------------------

report=$(parity_report "$ROOT/$CLAUDE_REL" "$ROOT/$CODEX_REL")
if [ -z "$report" ]; then
  n_skills=$(cd "$ROOT/$CLAUDE_REL" && ls -d plan-* | wc -l | tr -d ' ')
  n_tok=$(for s in $(cd "$ROOT/$CLAUDE_REL" && ls -d plan-*); do
    tokens "$ROOT/$CLAUDE_REL/$s/SKILL.md"; done | sort -u | wc -l | tr -d ' ')
  n_gates=$(gates | grep -c .)
  ok "adapter parity: $n_skills skill pairs, $n_tok distinct vocabulary tokens, $n_gates named gates, no divergence"
else
  while IFS= read -r line; do bad "adapter divergence: $line"; done <<<"$report"
fi

# --- run 1b: both CLIs are wired to the same skill set -----------------------

# An adapter directory nobody links is an adapter nobody has: the
# module links each skill directory per CLI by hand, so a skill wired
# for one orchestrator and not the other diverges in effect even when
# both files exist.
wiring_report() { # wiring_report <plan-skills.nix>
  local nix=$1 sk side
  for sk in $(cd "$ROOT/$CLAUDE_REL" && ls -d plan-*); do
    for side in claude codex; do
      grep -qF "\".$side/skills/$sk\".source" "$nix" ||
        echo "wiring: $sk is not linked for $side in $(basename "$nix")"
    done
  done
}

wiring=$(wiring_report "$WIRING")
if [ -z "$wiring" ]; then
  ok "both CLIs are wired to every plan-* adapter in $(basename "$WIRING")"
else
  while IFS= read -r line; do bad "$line"; done <<<"$wiring"
fi

# --- run 2: every exemption still earns its place ----------------------------

while IFS='|' read -r s side tok why; do
  [ -n "${tok:-}" ] || continue
  hits=0
  for sk in $(cd "$ROOT/$CLAUDE_REL" && ls -d plan-*); do
    [ "$s" = '*' ] || [ "$s" = "$sk" ] || continue
    [ "$side" = claude ] && f="$ROOT/$CLAUDE_REL/$sk/SKILL.md" || f="$ROOT/$CODEX_REL/$sk/SKILL.md"
    [ -f "$f" ] || continue
    # Herestring, never a pipeline: grep -q exits at the first match and
    # under pipefail the producer's SIGPIPE would read as "no match".
    toks=$(tokens "$f")
    if grep -qxF -- "$tok" <<<"$toks"; then hits=$((hits + 1)); fi
  done
  if [ "$hits" -gt 0 ]; then
    ok "exemption earns its place: $tok ($side, $hits file(s)) - $why"
  else
    bad "stale exemption: $tok is exempt for $side but appears nowhere; delete the entry"
  fi
done < <(exemptions)

# --- run 2b: every gate still matches something ------------------------------

# A gate whose alternates match no adapter at all is either misspelled
# or describes a rule that has left the family; either way it silently
# stops enforcing anything, so it fails rather than reading green.
live_keys=$(for sk in $(cd "$ROOT/$CLAUDE_REL" && ls -d plan-*); do
  for side in "$CLAUDE_REL" "$CODEX_REL"; do
    [ -f "$ROOT/$side/$sk/SKILL.md" ] || continue
    gate_hits "$ROOT/$side/$sk/SKILL.md"
  done
done | sort -u)
stale=$(comm -23 <(cut -d'|' -f1 "$GATES_FILE" | sort -u) <(echo "$live_keys"))
if [ -z "$stale" ]; then
  ok "every gate matches live adapter text ($(grep -c . "$GATES_FILE") gates)"
else
  while IFS= read -r key; do
    [ -n "$key" ] || continue
    bad "stale gate: '$key' matches no adapter; fix the pattern or drop the gate"
  done <<<"$stale"
fi

# --- run 2c: the gate registry covers every named step ----------------------

coverage=$(step_coverage_report "$ROOT/$CLAUDE_REL")
counts=$(grep '^counts: ' <<<"$coverage" | sed 's/^counts: //')
findings=$(grep -v '^counts: ' <<<"$coverage" || true)
if [ -z "$findings" ]; then
  ok "every named step is registry-covered ($counts)"
else
  while IFS= read -r line; do bad "$line"; done <<<"$findings"
fi

# --- run 2d: every linked condition still permits its action ----------------

conditions=$(condition_report "$ROOT/$CLAUDE_REL" "$ROOT/$CODEX_REL")
if [ -z "$conditions" ]; then
  ok "every action is still gated by its condition ($(requires | grep -c .) links)"
else
  while IFS= read -r line; do bad "$line"; done <<<"$conditions"
fi

# --- run 2e: the unpoliced region is unchanged -------------------------------

if [ "${UPDATE_UNPOLICED:-}" = 1 ]; then
  unpoliced=""
  unpoliced_clauses "$ROOT/$CLAUDE_REL" "$ROOT/$CODEX_REL" | sort > "$UNPOLICED_SNAPSHOT"
  ok "unpoliced snapshot regenerated ($(grep -c . "$UNPOLICED_SNAPSHOT") clause remainders) - review the diff: every line is adapter text no registry entry covers, so check its counterpart changed too"
else
  unpoliced=$(unpoliced_report "$ROOT/$CLAUDE_REL" "$ROOT/$CODEX_REL")
  if [ -z "$unpoliced" ]; then
    ok "unpoliced region unchanged ($(grep -c . "$UNPOLICED_SNAPSHOT") clause remainders the registry does not cover)"
  else
    while IFS= read -r line; do bad "$line"; done <<<"$unpoliced"
    bad "the unpoliced region changed: register the rule as a gate if it is one, or confirm the counterpart adapter carries the same change and regenerate with UPDATE_UNPOLICED=1"
  fi
fi

# --- run 3: negative controls ------------------------------------------------

# Each control copies both trees, breaks parity one way, and asserts the
# engine names it. A control that reports nothing means the engine has
# stopped detecting that class of divergence.
control() { # control <description> <expected substring> <mutator> [engine]
  local desc=$1 want=$2 mutate=$3 engine=${4:-parity_report} tmp out
  # A control proves the engine reports a divergence it alone
  # introduced, which only means anything from a clean baseline. On an
  # already-divergent tree a control whose fixture touches the same
  # clause as the real divergence reports nothing new and would read as
  # a broken engine, so skip instead of misreporting: fix the
  # divergence run 1 named, then the controls speak again.
  if [ -n "$report$conditions$unpoliced" ]; then
    echo "ok - negative control skipped, the tree is already divergent: $desc # SKIP"
    return
  fi
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/adapter-parity.XXXXXX")
  mkdir -p "$tmp/claude" "$tmp/codex"
  cp -R "$ROOT/$CLAUDE_REL/." "$tmp/claude/"
  cp -R "$ROOT/$CODEX_REL/." "$tmp/codex/"
  "$mutate" "$tmp"
  out=$("$engine" "$tmp/claude" "$tmp/codex")
  rm -rf "$tmp"
  if grep -qF -- "$want" <<<"$out"; then
    ok "negative control caught: $desc"
  else
    bad "negative control NOT caught ($desc); report was: ${out:-<empty>}"
  fi
}

# A step removed from one adapter: drop the recovery arm that opens an
# existing checkout out of codex's plan-implement.
mutate_step() {
  perl -0pi -e 's/\bherdr worktree open\b/the recovery arm/' "$1/codex/plan-implement/SKILL.md"
}
# A whole skill missing on one side.
mutate_skill_set() { rm -rf "$1/codex/plan-sync"; }
# Frontmatter drift.
mutate_description() {
  perl -0pi -e 's/^description: /description: Updated. /m' "$1/claude/plan-sync/SKILL.md"
}
# A prose-only gate deleted: the verify-round escalation cap.
mutate_gate() {
  perl -0pi -e 's/Three verify rounds.*?another round\.//s' \
    "$1/claude/plan-item-review/SKILL.md"
}
# A flag dropped from a command.
mutate_flag() {
  perl -0pi -e 's/--no-focus//g' "$1/codex/plan-implement/SKILL.md"
}
# The prerequisite of a gate removed, leaving the actions it permits in
# place - the 2026-10-19 conformance escape. Once from each side,
# because an action keeping its condition on one adapter only is the
# divergence; and once from both at the same time, which parity cannot
# see by construction and layer 5 is there to catch.
mutate_condition_claude() {
  perl -0pi -e "s/On the human's explicit approval: //" "$1/claude/plan-create/SKILL.md"
}
mutate_condition_codex() {
  perl -0pi -e 's/on their explicit sign-off flip/flip/' "$1/codex/plan-create/SKILL.md"
}
mutate_condition_both() {
  mutate_condition_claude "$1"
  mutate_condition_codex "$1"
}

# An edit inside the region no registry entry covers, in both
# directions: a clause deleted from one adapter, and a clause added to
# one. Neither changes a registered gate or a token, which is the
# whole point of layer 6.
mutate_unpoliced_delete() {
  perl -0pi -e 's/Do not take the\s+session.s memory of the work as the record;\s+//s' \
    "$1/claude/plan-sync/SKILL.md"
}
mutate_unpoliced_add() {
  perl -0pi -e 's/^Steps:$/Steps:\n\nPrefer the blue path over the green one when the moon is full./m' \
    "$1/claude/plan-sync/SKILL.md"
}

# One prerequisite deleted from the middle of a clause whose other
# half a gate matches - the audit-3 escape, where clause-level
# coverage treated the whole clause as accounted for.
mutate_partial_prerequisite() {
  perl -0pi -e 's/ and its pane is closed,//' "$1/claude/plan-sync/SKILL.md"
}
# The same boundary with nothing registered on either half: a fragment
# that only layer 6's remainder can see.
mutate_partial_fragment() {
  perl -0pi -e 's/, as always//' "$1/claude/plan-create/SKILL.md"
}

# A whole named step deleted from one adapter - the round-1 escape: the
# frontmatter description still mentions plan-item-review and plan-sync,
# so the token sets alone concealed it.
mutate_full_step() {
  perl -0pi -e 's/7\. \*\*Review gate\.\*\*.*?plan-sync` skill\.\n//s' \
    "$1/claude/plan-implement/SKILL.md"
}

control "a step removed from one adapter" "cli:worktree open" mutate_step
control "a skill missing for one orchestrator" "shape: skill present for claude and missing for codex: plan-sync" mutate_skill_set
control "a description edited on one side only" "shape: plan-sync: descriptions differ" mutate_description
control "a prose-only gate deleted" "gate: plan-item-review: codex covers 'verify-round-cap'" mutate_gate
control "a flag dropped from a command" "flag:--no-focus" mutate_flag
control "a whole named step deleted" "gate: plan-implement: codex covers 'review-gate-invokes-item-review'" mutate_full_step
control "a gate's prerequisite removed from the claude side" "gate: plan-create: codex covers 'signoff-needs-explicit-approval'" mutate_condition_claude
control "a gate's prerequisite removed from the codex side" "gate: plan-create: claude covers 'signoff-needs-explicit-approval'" mutate_condition_codex
control "a prerequisite dropped from both sides at once" "action without its condition: plan-create (claude): 'signoff-flips-status' is stated but 'signoff-needs-explicit-approval' is not" mutate_condition_both condition_report
control "a prerequisite deleted from inside a matched clause" "gate: plan-sync: codex covers 'teardown-needs-pane-closed'" mutate_partial_prerequisite
control "an unregistered fragment deleted from inside a matched clause" "unpoliced text vanished: claude/plan-create: Pause for the human [gate] , as always" mutate_partial_fragment unpoliced_report
control "a clause deleted from the unpoliced region" "unpoliced text vanished: claude/plan-sync: Do not take the session's memory" mutate_unpoliced_delete unpoliced_report
control "a clause added to the unpoliced region" "unpoliced text appeared: claude/plan-sync: Prefer the blue path" mutate_unpoliced_add unpoliced_report

# Layer 4's own control: a step the registry does not know about must
# be reported, or the audit would silently bless future steps.
step_tmp=$(mktemp -d "${TMPDIR:-/tmp}/adapter-parity-steps.XXXXXX")
cp -R "$ROOT/$CLAUDE_REL/." "$step_tmp/"
perl -0pi -e 's/^8\. /9. **Fabricate.** Invent an unregistered instruction nothing in the gate registry matches.\n8. /m' \
  "$step_tmp/plan-implement/SKILL.md"
# Captured, not piped: grep -q exits at the first match and under
# pipefail the producer's SIGPIPE would read as "nothing reported".
step_out=$(step_coverage_report "$step_tmp")
if [ -n "$findings" ]; then
  echo "ok - negative control skipped, the tree is already divergent: a named step no gate covers # SKIP"
elif grep -qF "uncovered step: plan-implement" <<<"$step_out"; then
  ok "negative control caught: a named step no gate covers"
else
  bad "negative control NOT caught (a named step no gate covers)"
fi
rm -rf "$step_tmp"

# One CLI's link dropped from the module: the files stay in step, the
# installed skill set does not.
wiring_tmp=$(mktemp "${TMPDIR:-/tmp}/plan-skills-nix.XXXXXX")
grep -vF '".codex/skills/plan-sync".source' "$WIRING" > "$wiring_tmp"
wiring_out=$(wiring_report "$wiring_tmp")
if [ -n "$wiring" ]; then
  echo "ok - negative control skipped, the tree is already divergent: an adapter wired for one CLI only # SKIP"
elif grep -qF "plan-sync is not linked for codex" <<<"$wiring_out"; then
  ok "negative control caught: an adapter wired for one CLI only"
else
  bad "negative control NOT caught (an adapter wired for one CLI only)"
fi
rm -f "$wiring_tmp"

exit $fail
