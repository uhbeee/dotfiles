# plan-feedback - bounded-wait feedback poll for a plan-publish session.
# Installed via pkgs/plan-publish; runtime tools come from the wrapper's
# closure, not the caller's PATH.

usage() {
  cat <<'EOF'
Usage: plan-feedback <file.md> [--timeout <seconds>] [--reply <text>]

Poll the lavish review session that plan-publish opened for this
markdown file, waiting a bounded time for reviewer feedback. Prints the
poll payload to stdout and encodes the outcome in the exit code, so an
orchestrator can always distinguish feedback from silence and never
hangs. A timeout means no feedback yet - it is NEVER approval.

Options:
  --timeout <seconds>  how long to wait before giving up (default 300).
                       The client watchdog allows this full timeout
                       plus about 15 seconds for startup and termination.
                       An unresponsive server can take that entire time
                       to produce exit 11; detection is not limited to
                       the extra 15 seconds
  --reply <text>       show a short agent reply in the session's
                       Conversation panel before waiting
  --help               show this help

Exit codes:
  0   feedback returned; payload on stdout. If it contains
      "session_ended: true" this was the reviewer's final send-and-end;
      do not republish uninvited
  10  no feedback before the timeout (poll again later; not approval)
  11  session unavailable: source never published, no session exists
      for it (for example the lavish state was cleared), or the lavish
      server stopped responding mid-poll ("unresponsive" on stderr) -
      run plan-publish first, or retry for the unresponsive case
  12  session already ended by the reviewer; nothing more will arrive
  13  last review window disconnected during this poll and its reconnect
      grace expired before the timeout; session resumable - ask the reviewer.
      Upstream limitation: a window already closed before polling begins
      can yield timeout 10 instead
  1   anything else

Durability and recovery:
  Delivery is written straight into the session's cache directory: each
  poll's raw payload lands in an inflight.<time>.<pid> file there the
  moment lavish delivers it, and is then appended as one JSON line
  ({ts, outcome, exit, payload}) to feedback.log BEFORE this command
  returns. A payload therefore survives the loss of the calling shell
  at ANY point:
    - after this command returned: read the log. Both "feedback" and
      "recovered" entries carry delivered payloads, and one run can
      log several, so list them all (delivery order) and disposition
      every entry you have not yet handled:
        jq -s 'map(select(.outcome == "feedback"
                       or .outcome == "recovered"))' <log>
    - interrupted between delivery and return (killed wrapper, even
      SIGKILL): the payload stays in its inflight file; the next
      plan-feedback run recovers it - appending one "recovered" log
      entry per file and returning the payloads as that run's result
      (exit 0). A file is recovered only once its poll's processes
      have fully exited - never while any process still holds it
      open - so a poll that lingers after its wrapper died (normally
      until its requested server timeout; an unresponsive or stopped
      orphan can linger longer) delays recovery to a later
      run but never loses the payload.
  Feedback the reviewer queued but no poll has delivered yet survives
  inside lavish: polls are safe to stop and re-run; each payload is
  delivered exactly once, to the poll that returns it. Prefer SIGTERM
  or SIGINT to stop a running plan-feedback (the in-flight poll is
  torn down cleanly and queued feedback stays queued); every
  annotation also remains visible in the session's Conversation panel
  in the browser.
EOF
}

# Nearest ancestor holding a .git entry (a directory for a plain repo,
# a file for a git worktree) - the repository root, found without a
# git dependency. Empty output if the path is not inside a repository.
repo_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    if [ -e "$d/.git" ]; then printf '%s\n' "$d"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}

# Resolve this source's session cache directory - identical logic to
# plan-publish's cache_dir so the two always agree on the session. The
# cache base is canonicalized to an absolute path (session identity
# never depends on the caller's cwd), and a cache location inside the
# source's own repository is refused: generated state lives outside the
# repo (decision 14), never in a tracked plan directory.
cache_dir() { # src name key
  local src="$1" name="$2" key="$3" base repo
  base="${XDG_CACHE_HOME:-$HOME/.cache}"
  # A relative cache base resolves against the caller's cwd, so the
  # same value would name different sessions from different
  # directories. Require an absolute path (the XDG spec deems a
  # relative XDG_CACHE_HOME invalid); the default $HOME/.cache already
  # is one.
  case "$base" in
    /*) : ;;
    *)
      echo "plan-feedback: XDG_CACHE_HOME must be an absolute path: $base" >&2
      echo "plan-feedback: a relative cache path names a different session per working directory" >&2
      exit 1
      ;;
  esac
  if ! base="$(realpath -m "$base" 2>/dev/null)"; then
    echo "plan-feedback: cannot resolve cache directory: $base" >&2
    exit 1
  fi
  repo="$(repo_root "$(dirname "$src")" || true)"
  if [ -n "$repo" ]; then
    case "$base/" in
      "$repo"/*)
        echo "plan-feedback: refusing a cache directory inside the source repository" >&2
        echo "plan-feedback:   repository: $repo" >&2
        echo "plan-feedback:   cache:      $base" >&2
        echo "plan-feedback: set XDG_CACHE_HOME to a location outside the repository" >&2
        exit 1
        ;;
    esac
  fi
  printf '%s\n' "$base/plan-publish/$name-$key"
}

src=""
timeout_s=300
reply=""
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --timeout) shift; timeout_s="${1:?--timeout needs a value}" ;;
    --reply) shift; reply="${1:?--reply needs a value}" ;;
    -*) echo "plan-feedback: unknown option: $1" >&2; usage >&2; exit 1 ;;
    *)
      if [ -n "$src" ]; then
        echo "plan-feedback: exactly one source file expected" >&2; exit 1
      fi
      src="$1"
      ;;
  esac
  shift
done

if [ -z "$src" ]; then
  usage >&2; exit 1
fi
case "$timeout_s" in
  ''|*[!0-9]*) echo "plan-feedback: --timeout must be a whole number of seconds" >&2; exit 1 ;;
esac
if [ "$timeout_s" -lt 1 ]; then
  echo "plan-feedback: --timeout must be at least 1 second" >&2; exit 1
fi
given="$src"
if ! src="$(realpath -e "$src" 2>/dev/null)"; then
  echo "plan-feedback: no such file: $given" >&2; exit 1
fi

name="$(basename "$src")"
name="${name%.*}"
key="$(printf '%s' "$src" | sha256sum | cut -c1-16)"
dir="$(cache_dir "$src" "$name" "$key")"
html="$dir/$name.html"

if [ ! -f "$html" ]; then
  echo "plan-feedback: not published: no render for $src" >&2
  echo "plan-feedback: run: plan-publish $src" >&2
  exit 11
fi

session_status() {
  awk '/^session:/{s=1;next} s && /^  status:/{print $2; exit}' <<<"$1"
}

log_payload() { # outcome exit payload
  jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg outcome "$1" \
    --argjson exit "$2" --arg payload "$3" \
    '{ts: $ts, outcome: $outcome, exit: $exit, payload: $payload}' \
    >> "$dir/feedback.log"
}

# Recover interrupted deliveries: a payload lavish delivered to a poll
# whose wrapper died sits in that run's inflight file. Fold any such
# feedback into the log and return it as this run's result. A file is
# touched only once its writer has demonstrably finished: the wrapper
# pid in the name must be dead (a live run may still spawn its poll)
# AND no process may still hold the file open (lsof) - the poll child
# keeps the file open as stdout for its whole life, so an orphaned or
# stalled child, however long it lingers, is skipped rather than
# unlinked under it. A child forked but not yet holding the file
# opens the path - not a removed inode - when it starts writing, so
# even that window cannot lose a payload.
recovered=""
for f in "$dir"/inflight.*; do
  [ -e "$f" ] || continue
  pid="${f##*.}"
  case "$pid" in ''|*[!0-9]*) continue ;; esac
  if kill -0 "$pid" 2>/dev/null; then continue; fi
  if [ -n "$(lsof -t "$f" 2>/dev/null)" ]; then continue; fi
  payload="$(cat "$f")"
  if [ "$(session_status "$payload")" = "feedback" ]; then
    log_payload "recovered" 0 "$payload"
    recovered="${recovered}${payload}
"
  fi
  rm -f "$f"
done
if [ -n "$recovered" ]; then
  printf '%s' "$recovered"
  {
    echo "plan-feedback: outcome: feedback (recovered from an interrupted delivery)"
    echo "plan-feedback: log:     $dir/feedback.log"
  } >&2
  exit 0
fi

# Use one server-side poll for the requested wait. Ending an intermediate
# poll clears lavish's browser-disconnect timer, so slicing the wait can
# hide a disconnect even after its reconnect grace has elapsed.
# A poll orphaned by SIGKILL can hold the session until its server timeout;
# its delivery still lands in the inflight file above. The poll also runs
# under a client-side deadline, because --timeout-ms only bounds the
# server-side wait - server startup and the poll request itself would
# otherwise hang unboundedly if the server stops responding.
# SIGTERM/SIGINT tear the child down promptly, which closes its
# connection before delivery, so lavish requeues.
grace_s=10
child=""
inflight="$dir/inflight.$(date +%s).$$"
# shellcheck disable=SC2329  # invoked via the trap below
on_signal() {
  if [ -n "$child" ]; then kill "$child" 2>/dev/null || true; fi
  exit 143
}
trap on_signal TERM INT

out=""
poll_exit=0
abandoned=0
poll_once() { # cap_s, then lavish-axi poll args
  local cap_s="$1" rc=0 ticks=0 state=""
  shift
  : > "$inflight"
  lavish-axi poll "$@" >"$inflight" 2>&1 &
  child=$!
  # Bounded wait without blind signalling: an overdue child may still
  # carry an undelivered payload in its socket, and killing a stopped
  # process destroys that payload before it can be flushed.
  while kill -0 "$child" 2>/dev/null && [ "$ticks" -lt $(( cap_s * 2 )) ]; do
    sleep 0.5
    ticks=$(( ticks + 1 ))
  done
  if kill -0 "$child" 2>/dev/null; then
    state="$(ps -o stat= -p "$child" 2>/dev/null || true)"
    case "$state" in
      *T*|*t*|"")
        # Stopped (SIGSTOP, job control, or debugger) - or the state
        # is unknown because ps failed or came back empty: signalling
        # is only proven safe for a running process, so abandon the
        # child untouched. It keeps the inflight file open, so the
        # recovery sweep skips the file; if the process ever resumes
        # and flushes feedback, a later run recovers it from that
        # still-linked file. Its payload is left for that sweep (not
        # read here): the writer is still live, so the file may be
        # partial, and consuming it now while also leaving it would
        # deliver it twice.
        child=""
        abandoned=1
        out=""
        ;;
      *)
        # Running but past the deadline: graceful TERM (closes the
        # connection pre-delivery, so lavish requeues), then KILL.
        kill "$child" 2>/dev/null || true
        ticks=0
        while kill -0 "$child" 2>/dev/null && [ "$ticks" -lt 10 ]; do
          sleep 0.5
          ticks=$(( ticks + 1 ))
        done
        kill -9 "$child" 2>/dev/null || true
        wait "$child" 2>/dev/null || true
        child=""
        out="$(cat "$inflight")"
        ;;
    esac
    poll_exit=124
    return 0
  fi
  wait "$child" || rc=$?
  child=""
  out="$(cat "$inflight")"
  poll_exit=$rc
}

poll_args=("$html" --timeout-ms "$(( timeout_s * 1000 ))")
if [ -n "$reply" ]; then
  poll_args+=(--agent-reply "$reply")
fi
poll_once "$(( timeout_s + grace_s ))" "${poll_args[@]}"
status="$(session_status "$out")"

# A payload that reached the inflight file wins over the exit code:
# even a watchdog-killed poll may have received feedback first.
if [ "$status" = "feedback" ]; then
  outcome="feedback"; exit_code=0
elif [ "$status" = "ended" ]; then
  outcome="ended"; exit_code=12
elif [ "$status" = "browser_disconnected" ]; then
  outcome="disconnected"; exit_code=13
elif grep -q '^code: NOT_FOUND$' <<<"$out"; then
  outcome="unavailable"; exit_code=11
elif [ "$poll_exit" -eq 124 ] \
  || grep -q '^code: SERVER_ERROR$' <<<"$out"; then
  # our deadline fired mid-request, or the CLI's own health checks
  # found the server unresponsive - either way the session cannot
  # answer right now
  outcome="unresponsive"; exit_code=11
elif [ "$poll_exit" -ne 0 ]; then
  outcome="error"; exit_code=1
elif [ "$status" = "waiting" ]; then
  outcome="timeout"; exit_code=10
else
  outcome="error"; exit_code=1
fi

# Decision 15: persist the payload before returning it, so an
# orchestrator lost between poll and disposition can recover it.
log_payload "$outcome" "$exit_code" "$out"
# An abandoned (stopped) child still holds the inflight file; leave it
# for a later run's sweep so a resumed flush cannot hit an unlinked
# path.
if [ "$abandoned" -eq 0 ]; then
  rm -f "$inflight"
fi

printf '%s\n' "$out"
{
  echo "plan-feedback: outcome: $outcome"
  echo "plan-feedback: log:     $dir/feedback.log"
} >&2
exit "$exit_code"
