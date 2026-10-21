#!/usr/bin/env bash
# Subagent pane reporting: the rendered half, mechanically.
#
# home/.claude/hooks/subagent-pane-metadata.sh reports the orchestrator's
# in-process children on its herdr pane. It long reported them as metadata
# tokens only, which herdr 0.9.0 stores and renders nowhere - so the reporting
# was real, API-readable, and invisible to the human it exists for (found in
# review, 2026-10-21; see PROTOCOL.md's Status section). The fix summarises the
# live roster into one `--display-agent` override, the one thing the agents
# panel draws.
#
# This check exists so that fix cannot silently regress to token-only. It needs
# no herdr: HERDR_BIN_PATH points the hook at a stub that records its argv, and
# the assertions read that log. What it pins is the contract a human sees -
# a display override while any child lives, the count when several do, the
# label upgrade at the parent's Stop, and the override cleared when the last
# child goes - plus the two lifecycle guards the hook's own comments promise
# (a compaction never sweeps live children; outside herdr nothing is reported).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
HOOK="$ROOT/home/.claude/hooks/subagent-pane-metadata.sh"
fail=0
ok() { echo "ok - $1"; }
bad() { echo "not ok - $1"; fail=1; }

[ -f "$HOOK" ] || { echo "not ok - hook missing at $HOOK"; exit 1; }

if ! command -v python3 >/dev/null 2>&1; then
  # The hook itself exits early without python3, so there is nothing to pin.
  ok "skipped: no python3, the hook no-ops without it"
  exit 0
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/subagent-hook-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

# --- stub herdr: records argv, answers `agent list` with a canned pane ---------
stub="$tmp/herdr"
cat >"$stub" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HERDR_STUB_LOG"
if [ "${1:-}" = "agent" ] && [ "${2:-}" = "list" ]; then
  printf '%s\n' '{"result":{"agents":[{"name":"exec-probe","pane_id":"t1:p1","agent":"claude"}]}}'
fi
exit 0
STUB
chmod +x "$stub"

log="$tmp/calls.log"
: >"$log"

fire() { # fire <action> <json payload> [env assignments...]
  local action=$1 payload=$2
  shift 2
  env HERDR_ENV=1 HERDR_PANE_ID=t1:p1 HERDR_SOCKET_PATH=/dev/null \
      HERDR_BIN_PATH="$stub" HERDR_STUB_LOG="$log" \
      HERDR_SUBAGENT_TOAST_MS=0 TMPDIR="$tmp/state" \
      "$@" bash "$HOOK" "$action" <<<"$payload" >/dev/null 2>&1 || true
}

since() { # since <line number> - calls recorded after that point
  tail -n "+$(( $1 + 1 ))" "$log" 2>/dev/null || true
}
count() { wc -l <"$log" | tr -d ' '; }

mkdir -p "$tmp/state"

has() { # has <string> <needle> <message>
  case "$1" in *"$2"*) ok "$3";; *) bad "$3 (got: ${1:-<nothing>})";; esac
}
hasnt() { # hasnt <string> <needle> <message>
  case "$1" in *"$2"*) bad "$3 (got: $1)";; *) ok "$3";; esac
}

# --- 1. outside herdr, nothing is reported ------------------------------------
before=$(count)
env -u HERDR_ENV HERDR_PANE_ID=t1:p1 HERDR_SOCKET_PATH=/dev/null \
    HERDR_BIN_PATH="$stub" HERDR_STUB_LOG="$log" TMPDIR="$tmp/state" \
    bash "$HOOK" subagent-start \
    <<<'{"session_id":"s1","agent_id":"ag_a","agent_type":"Explore"}' \
    >/dev/null 2>&1 || true
if [ "$(count)" = "$before" ]; then
  ok "outside herdr the hook reports nothing"
else
  bad "outside herdr the hook called herdr anyway: $(since "$before")"
fi

# --- 2. one child: token AND rendered override, in a single call ---------------
before=$(count)
fire subagent-start '{"session_id":"s1","agent_id":"ag_a","agent_type":"Explore"}'
one=$(since "$before")
reports=$(printf '%s\n' "$one" | grep -c 'pane report-metadata' || true)
if [ "$reports" = 1 ]; then
  ok "a child event writes token and override in one report call"
else
  bad "a child event should write one report call (got: $one)"
fi
has "$one" "--token sub_ag_a=Explore: working" "the child's token carries label and activity"
has "$one" "--display-agent" "a live child sets the rendered display override"
has "$one" "exec-probe +Explore" "the override keeps the pane's own agent name"

# --- 3. the child's activity reaches the override, and the name is cached -----
before=$(count)
fire pre-tool '{"session_id":"s1","agent_id":"ag_a","tool_name":"Bash"}'
next_call=$(since "$before")
has "$next_call" "exec-probe +Explore: Bash" "a tool call shows in the override"
hasnt "$next_call" "agent list" "the pane's agent name is read once per session, not per event"

# --- 4. two children: the count and both labels -------------------------------
before=$(count)
fire subagent-start '{"session_id":"s1","agent_id":"ag_b","agent_type":"general-purpose"}'
two=$(since "$before")
has "$two" "+2 subagents" "overlapping children report their count"
has "$two" "Explore, general-purpose" "overlapping children report both labels"
has "$two" "--token sub_ag_b=" "the second child gets its own token"

# --- 5. one stops, the other stays visible ------------------------------------
before=$(count)
fire subagent-stop '{"session_id":"s1","agent_id":"ag_a"}'
gone=$(since "$before")
has "$gone" "--clear-token sub_ag_a" "a stopped child's token is cleared"
has "$gone" "exec-probe +general-purpose" "the surviving child stays in the override"
hasnt "$gone" "--clear-display-agent" "the override is not cleared while a child lives"

# --- 6. the parent's Stop upgrades labels to task descriptions ----------------
before=$(count)
fire stop '{"session_id":"s1","background_tasks":[{"type":"subagent","id":"ag_b","description":"audit the suite"}]}'
has "$(since "$before")" "audit the suite" "the Stop sweep upgrades a label to its task description"

# --- 7. a compaction must not sweep live children -----------------------------
before=$(count)
fire session '{"session_id":"s1","source":"compact"}'
hasnt "$(since "$before")" "--clear" "SessionStart source=compact clears nothing"

# --- 8. the last child going clears the override ------------------------------
before=$(count)
fire subagent-stop '{"session_id":"s1","agent_id":"ag_b"}'
empty=$(since "$before")
has "$empty" "--clear-token sub_ag_b" "the last child's token is cleared"
has "$empty" "--clear-display-agent" "the override is cleared when no child is left"

# --- 9. SessionEnd clears the override too ------------------------------------
fire subagent-start '{"session_id":"s1","agent_id":"ag_c","agent_type":"Plan"}'
before=$(count)
fire session-end '{"session_id":"s1"}'
end=$(since "$before")
has "$end" "--clear-token sub_ag_c" "SessionEnd clears a child left behind"
has "$end" "--clear-display-agent" "SessionEnd clears the override"

# --- 10. no session state is left behind --------------------------------------
# The pane-level display lock is infrastructure and outlives any one session,
# so it is the one file expected to remain.
root="$tmp/state/claude-subagent-metadata"
leftovers=$(find "$root" -type f ! -name '.display.lock' 2>/dev/null | wc -l | tr -d ' ')
if [ "$leftovers" = 0 ]; then
  ok "the session's state directory is emptied on SessionEnd"
else
  bad "session state survived SessionEnd: $(find "$root" -type f ! -name '.display.lock')"
fi
if [ -f "$root/t1_p1/.display.lock" ]; then
  ok "the pane's display lock survives, as pane-level state should"
else
  bad "the pane's display lock is missing"
fi

# --- 11. an unresolvable agent name still renders -----------------------------
broken="$tmp/herdr-broken"
cat >"$broken" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HERDR_STUB_LOG"
exit 0
STUB
chmod +x "$broken"
before=$(count)
env HERDR_ENV=1 HERDR_PANE_ID=t1:p1 HERDR_SOCKET_PATH=/dev/null \
    HERDR_BIN_PATH="$broken" HERDR_STUB_LOG="$log" HERDR_SUBAGENT_TOAST_MS=0 \
    TMPDIR="$tmp/state" bash "$HOOK" subagent-start \
    <<<'{"session_id":"s2","agent_id":"ag_d","agent_type":"Explore"}' \
    >/dev/null 2>&1 || true
has "$(since "$before")" "claude +Explore" "an unreadable agent list falls back to the kind"

# --- 12. nested sessions share the pane, and must not blank each other --------
# State is per (pane, session) because a nested child session shares its
# parent's pane; the display override is per (pane, source) only. So every
# roster on the pane feeds the summary, or the cases below would hide a live
# child whose own session has no event coming - the parent sitting in one long
# silent tool call is an explicit acceptance case, not a hypothetical.
fire session-end '{"session_id":"s2"}'          # leave the pane empty first
fire subagent-start '{"session_id":"parent","agent_id":"ag_p","agent_type":"Explore"}'

before=$(count)
fire session-end '{"session_id":"nested"}'
nested_end=$(since "$before")
hasnt "$nested_end" "--clear-display-agent" "a nested session ending does not clear a live override"
has "$nested_end" "exec-probe +Explore" "a nested session ending rewrites the parent's child"

before=$(count)
fire stop '{"session_id":"nested","background_tasks":[]}'
hasnt "$(since "$before")" "--clear-display-agent" "a nested empty Stop sweep keeps the parent's child"

before=$(count)
fire session '{"session_id":"nested","source":"startup"}'
hasnt "$(since "$before")" "--clear-display-agent" "a nested session restarting keeps the parent's child"

before=$(count)
fire subagent-start '{"session_id":"nested","agent_id":"ag_n","agent_type":"Plan"}'
has "$(since "$before")" "+2 subagents" "children of two sessions count as the pane's roster"

before=$(count)
fire subagent-stop '{"session_id":"nested","agent_id":"ag_n"}'
nested_stop=$(since "$before")
hasnt "$nested_stop" "--clear-display-agent" "the nested child stopping leaves the parent's visible"
has "$nested_stop" "exec-probe +Explore" "the override falls back to the remaining session's child"

before=$(count)
fire subagent-stop '{"session_id":"parent","agent_id":"ag_p"}'
has "$(since "$before")" "--clear-display-agent" "the pane's last child clears the override"

exit "$fail"
