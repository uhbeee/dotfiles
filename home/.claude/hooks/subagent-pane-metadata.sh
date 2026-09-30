#!/bin/sh
# Reports a Claude session's in-process subagents on its herdr pane.
#
# Herdr sees one agent per pane, so the orchestrator's own children - Agent
# tool calls - are invisible while they run. This hook writes one display-only
# metadata token per live child on the pane (`herdr pane report-metadata`,
# source below) and clears it when the child stops.
#
# Deliberately NOT named herdr-*: it sits beside herdr's managed
# herdr-agent-state.sh, which herdr's integration installer owns and
# overwrites, and the name keeps the two namespaces apart. Nothing here
# reads or writes that script.
#
# Lifecycle strategy (spike 2026-09-29, Claude Code 2.1.236): tokens carry no
# expiry. They are cleared by the child's SubagentStop, by the session Stop
# sweep below when a stop event is missed, and by SessionEnd. A TTL cannot
# carry liveness here: the only events attributable to a child are its own
# SubagentStart/SubagentStop and its PreToolUse/PostToolUse, so a child inside
# one long tool call emits nothing at all - measured at 45.2s in the spike and
# 92s in the live run, with no upper bound - and no hook event of any kind
# fires meanwhile.
#
# Two lifecycle hazards the handlers below guard explicitly: SessionStart also
# fires with source "compact" on a compaction, while the session and its
# children carry on, so only a real (re)start sweeps; and a child's
# SubagentStop can run concurrently with the parent's Stop sweep, whose roster
# is a snapshot, so state mutations take an exclusive per-session lock and the
# sweep never creates a child it does not already know.
#
# Wired from ~/.claude/settings.json; no-ops outside herdr. Usage:
#   subagent-pane-metadata.sh <subagent-start|subagent-stop|pre-tool|post-tool|stop|session|session-end>

set -eu

action="${1:-}"
case "$action" in
  subagent-start|subagent-stop|pre-tool|post-tool|stop|session|session-end) ;;
  *) exit 0 ;;
esac

# Outside herdr, or without the pieces we need, this hook does nothing.
[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
[ -n "${HERDR_SOCKET_PATH:-}" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0
herdr_bin="${HERDR_BIN_PATH:-}"
[ -n "$herdr_bin" ] || herdr_bin="$(command -v herdr 2>/dev/null || true)"
[ -n "$herdr_bin" ] || exit 0

hook_input_file="$(mktemp "${TMPDIR:-/tmp}/claude-subagent-hook.XXXXXX")" || exit 0
trap 'rm -f "$hook_input_file"' EXIT HUP INT TERM
cat >"$hook_input_file" 2>/dev/null || true

# PreToolUse/PostToolUse fire on every tool call of every session; only the
# ones a child made carry a top-level agent_id. Cheap textual reject first, so
# the common case never pays for a python start.
case "$action" in
  pre-tool|post-tool)
    grep -q '"agent_id"' "$hook_input_file" 2>/dev/null || exit 0
    ;;
esac

SUBAGENT_ACTION="$action" \
SUBAGENT_HOOK_INPUT_FILE="$hook_input_file" \
SUBAGENT_HERDR_BIN="$herdr_bin" \
python3 - <<'PY' || true
import fcntl
import json
import os
import re
import shutil
import subprocess
import time

# One source of our own: metadata is per (pane, source), so this never
# collides with herdr's own reporting or with the plan-skills pane marks.
SOURCE = "claude:subagents"
TOKEN_PREFIX = "sub_"
LOCK_NAME = ".lock"
# SessionStart sources that mean a session is beginning from nothing, so none
# of our children can be live. Every other source - "compact", or anything a
# later version adds - is treated as the session continuing: losing a live
# child is the damaging direction, while a stale token is cleaned up by the
# next Stop sweep, by SessionEnd, or by the prune below.
RESTART_SOURCES = ("startup", "resume", "clear")
# Token names are limited to 32 chars of [A-Za-z0-9_-]; agent ids are 17.
TOKEN_MAX = 32
LABEL_MAX = 28
VALUE_MAX = 48
# Decision 11's completion-toast threshold. 0 disables the toasts.
TOAST_MS = 60000
# A state directory whose last event is older than this belongs to a session
# that died without SessionEnd; a later session in the same pane prunes it.
PRUNE_S = 24 * 3600

action = os.environ["SUBAGENT_ACTION"]
pane = os.environ["HERDR_PANE_ID"]
herdr = os.environ["SUBAGENT_HERDR_BIN"]

try:
    TOAST_MS = int(os.environ.get("HERDR_SUBAGENT_TOAST_MS", TOAST_MS))
except ValueError:
    pass

payload = {}
try:
    with open(os.environ["SUBAGENT_HOOK_INPUT_FILE"], encoding="utf-8") as handle:
        text = handle.read()
    if text.strip():
        payload = json.loads(text)
except Exception:
    payload = {}
if not isinstance(payload, dict):
    raise SystemExit(0)


def slug(value, keep="-"):
    return re.sub("[^A-Za-z0-9%s]" % keep, "_", str(value))


def token_name(agent_id):
    return (TOKEN_PREFIX + slug(agent_id, ""))[:TOKEN_MAX]


def herdr_call(args):
    try:
        subprocess.run(
            [herdr] + args,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=5,
        )
    except Exception:
        pass


def report(agent_id, label, activity):
    value = "%s: %s" % (label[:LABEL_MAX], activity)
    herdr_call(["pane", "report-metadata", pane, "--source", SOURCE,
                "--token", "%s=%s" % (token_name(agent_id), value[:VALUE_MAX])])


def clear(agent_id):
    herdr_call(["pane", "report-metadata", pane, "--source", SOURCE,
                "--clear-token", token_name(agent_id)])


def toast(title, body):
    herdr_call(["notification", "show", title, "--body", body, "--sound", "done"])


# State lives per pane per session: a nested child session shares its parent's
# pane, and must never sweep away the parent's live children.
pane_dir = os.path.join(
    os.environ.get("TMPDIR") or "/tmp", "claude-subagent-metadata", slug(pane, ""))
state_dir = os.path.join(pane_dir, slug(payload.get("session_id") or "unknown"))


def state_path(agent_id):
    return os.path.join(state_dir, slug(agent_id, ""))


def load(agent_id):
    try:
        with open(state_path(agent_id), encoding="utf-8") as handle:
            state = json.load(handle)
        return state if isinstance(state, dict) else {}
    except Exception:
        return {}


def save(agent_id, state):
    try:
        os.makedirs(state_dir, exist_ok=True)
        tmp = state_path(agent_id) + ".tmp"
        with open(tmp, "w", encoding="utf-8") as handle:
            json.dump(state, handle)
        os.replace(tmp, state_path(agent_id))
    except Exception:
        pass


def drop(agent_id):
    try:
        os.remove(state_path(agent_id))
    except Exception:
        pass


def live_ids():
    if not os.path.isdir(state_dir):
        return []
    return [name for name in sorted(os.listdir(state_dir))
            if not name.endswith(".tmp") and not name.startswith(".")]


def acquire_lock(may_create):
    """Serialise this session's state mutations, for the process lifetime.

    Concurrent hook processes are real: a background child's SubagentStop and
    the parent's Stop sweep are driven by different loops and can run at the
    same moment. Without this, the sweep's check-then-write races the stop and
    resurrects a child that just finished. Released when the process exits.
    """
    try:
        if not may_create and not os.path.isdir(state_dir):
            return None
        os.makedirs(state_dir, exist_ok=True)
        handle = os.open(os.path.join(state_dir, LOCK_NAME),
                         os.O_RDWR | os.O_CREAT, 0o600)
        fcntl.flock(handle, fcntl.LOCK_EX)
        return handle
    except Exception:
        return None


def touch(agent_id, label=None, activity=None, create=True):
    """Record or refresh a child, then report it. Returns its state.

    create=False is the Stop sweep's mode: its roster is a snapshot, so a
    child whose SubagentStop already landed must stay gone rather than be
    recreated with a fresh start time. The lock makes this check atomic.
    """
    if not create and not os.path.exists(state_path(agent_id)):
        return None
    state = load(agent_id)
    state.setdefault("start_ms", int(time.time() * 1000))
    if label:
        state["label"] = str(label)
    state.setdefault("label", "subagent")
    if activity:
        state["activity"] = activity
    state.setdefault("activity", "working")
    save(agent_id, state)
    report(agent_id, str(state["label"]), str(state["activity"]))
    return state


def forget_all():
    for agent_id in live_ids():
        clear(agent_id)
        drop(agent_id)
    # Only reached when the session is starting or over, so no other holder of
    # this lock exists; unlinking it lets the directory go instead of lingering
    # until the prune.
    try:
        os.remove(os.path.join(state_dir, LOCK_NAME))
    except Exception:
        pass
    try:
        os.rmdir(state_dir)
    except Exception:
        pass


agent_id = payload.get("agent_id")
agent_id = agent_id if isinstance(agent_id, str) and agent_id else None

if action in ("subagent-start", "pre-tool", "post-tool", "subagent-stop"):
    if not agent_id:
        raise SystemExit(0)

lock = acquire_lock(action in ("subagent-start", "pre-tool", "post-tool"))

if action == "subagent-start":
    touch(agent_id, label=payload.get("agent_type") or "subagent", activity="working")

elif action == "pre-tool":
    touch(agent_id, activity=str(payload.get("tool_name") or "working")[:16])

elif action == "post-tool":
    touch(agent_id, activity="thinking")

elif action == "subagent-stop":
    state = load(agent_id)
    clear(agent_id)
    drop(agent_id)
    started = state.get("start_ms")
    if TOAST_MS > 0 and isinstance(started, int):
        elapsed = int(time.time() * 1000) - started
        if elapsed >= TOAST_MS:
            seconds = elapsed // 1000
            spent = "%dm %ds" % (seconds // 60, seconds % 60) if seconds >= 60 \
                else "%ds" % seconds
            label = str(state.get("label") or "subagent")[:LABEL_MAX]
            toast("subagent done: %s" % label,
                  "ran %s in pane %s" % (spent, pane))

elif action == "stop":
    # The session's turn ended. background_tasks is herdr-independent truth
    # about which children are still alive, so this both upgrades labels to
    # the task descriptions and clears children whose stop event never came.
    if agent_id:
        raise SystemExit(0)
    tasks = payload.get("background_tasks")
    running = {}
    if isinstance(tasks, list):
        for task in tasks:
            if isinstance(task, dict) and task.get("type") == "subagent":
                task_id = task.get("id")
                if isinstance(task_id, str) and task_id:
                    running[slug(task_id, "")] = task.get("description") or ""
    for known in live_ids():
        if known in running:
            touch(known, label=running[known] or None, create=False)
        else:
            clear(known)
            drop(known)

elif action == "session":
    # Subagents get SubagentStart, not SessionStart, in this Claude Code - but
    # stay defensive, an agent-scoped SessionStart must not sweep the session.
    if agent_id:
        raise SystemExit(0)
    # A compaction replays SessionStart with source "compact" while the session
    # and its children keep running (reproduced on 2.1.236), so sweeping here
    # would blank live children and the start times their toasts are timed
    # from. Only a session beginning from nothing may sweep.
    if str(payload.get("source") or "") not in RESTART_SOURCES:
        raise SystemExit(0)
    forget_all()
    cutoff = time.time() - PRUNE_S
    try:
        stale = [name for name in os.listdir(pane_dir)
                 if os.path.getmtime(os.path.join(pane_dir, name)) < cutoff]
    except Exception:
        stale = []
    for name in stale:
        abandoned = os.path.join(pane_dir, name)
        try:
            orphans = os.listdir(abandoned)
        except Exception:
            orphans = []
        for child in orphans:
            if not child.endswith(".tmp"):
                clear(child)
        shutil.rmtree(abandoned, ignore_errors=True)

elif action == "session-end":
    forget_all()
PY
