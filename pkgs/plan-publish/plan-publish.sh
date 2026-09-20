# plan-publish - render a markdown file and open it as a lavish review
# session. Installed via pkgs/plan-publish; runtime tools come from the
# wrapper's closure, not the caller's PATH.

usage() {
  cat <<'EOF'
Usage: plan-publish <file.md> [--no-open] [--reopen]

Render a markdown file to self-contained HTML (pandoc, GitHub-flavored
markdown; local resources such as images are embedded, resolved
relative to the markdown file's directory) and open or refresh it as a
lavish-axi browser review session. The markdown file stays the master;
the render is disposable.

The render lands outside any repo, in a cache directory keyed by the
source's canonical absolute path:

  ${XDG_CACHE_HOME:-~/.cache}/plan-publish/<name>-<key>/
    <name>.html    the render (its path is the lavish session key)
    source         the canonical markdown path it was rendered from
    feedback.log   per-session feedback log written by plan-feedback
    inflight.*     interrupted feedback deliveries awaiting recovery
                   by the next plan-feedback run (see its --help)

Republishing the same source reuses the same directory, render path,
and lavish session - connected browsers live-reload. Distinct sources,
including same-named files in different directories, get distinct
sessions.

XDG_CACHE_HOME, if set, must be an absolute path outside the source's
repository; a relative value is rejected (it would name a different
session per working directory). Unset uses ~/.cache.

Options:
  --no-open   create or refresh the session without launching a browser
  --reopen    reopen a session the reviewer ended from the browser; use
              only after the reviewer has asked for another round
  --help      show this help

Exit codes:
  0   published (session opened or refreshed)
  20  the reviewer ended this session from the browser; rerun with
      --reopen once they have confirmed they want another round
  1   anything else

Retrieve feedback with: plan-feedback <file>
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

# Resolve this source's session cache directory. The cache base is
# canonicalized to an absolute path so a session's identity never
# depends on the caller's working directory, and a cache location
# inside the source's own repository is refused: the render and every
# byte of generated state must live outside the repo (decision 14),
# never in a tracked plan directory. Both plan-publish and plan-feedback
# compute this identically, so they always agree on the session.
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
      echo "plan-publish: XDG_CACHE_HOME must be an absolute path: $base" >&2
      echo "plan-publish: a relative cache path names a different session per working directory" >&2
      exit 1
      ;;
  esac
  if ! base="$(realpath -m "$base" 2>/dev/null)"; then
    echo "plan-publish: cannot resolve cache directory: $base" >&2
    exit 1
  fi
  repo="$(repo_root "$(dirname "$src")" || true)"
  if [ -n "$repo" ]; then
    case "$base/" in
      "$repo"/*)
        echo "plan-publish: refusing a cache directory inside the source repository" >&2
        echo "plan-publish:   repository: $repo" >&2
        echo "plan-publish:   cache:      $base" >&2
        echo "plan-publish: set XDG_CACHE_HOME to a location outside the repository" >&2
        exit 1
        ;;
    esac
  fi
  printf '%s\n' "$base/plan-publish/$name-$key"
}

src=""
open_args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --no-open|--reopen) open_args+=("$1") ;;
    -*) echo "plan-publish: unknown option: $1" >&2; usage >&2; exit 1 ;;
    *)
      if [ -n "$src" ]; then
        echo "plan-publish: exactly one source file expected" >&2; exit 1
      fi
      src="$1"
      ;;
  esac
  shift
done

if [ -z "$src" ]; then
  usage >&2; exit 1
fi
given="$src"
if ! src="$(realpath -e "$src" 2>/dev/null)"; then
  echo "plan-publish: no such file: $given" >&2; exit 1
fi

name="$(basename "$src")"
name="${name%.*}"
key="$(printf '%s' "$src" | sha256sum | cut -c1-16)"
dir="$(cache_dir "$src" "$name" "$key")"
html="$dir/$name.html"
title="$(basename "$(dirname "$src")")/$(basename "$src")"

mkdir -p "$dir"
printf '%s\n' "$src" > "$dir/source"
# --embed-resources inlines local images/CSS as data URIs so the
# render stays reviewable from the cache directory; relative paths are
# resolved against the source's directory, not the caller's cwd.
pandoc --standalone --embed-resources --from gfm --to html \
  --resource-path "$(dirname "$src")" --metadata title="$title" \
  --output "$html" "$src"

# lavish-axi exits 0 even when it refuses to reopen a session the
# reviewer ended from the browser; the refusal is only in the output.
out="$(lavish-axi "$html" "${open_args[@]}")"
printf '%s\n' "$out"
status="$(awk '/^session:/{s=1;next} s && /^  status:/{print $2; exit}' <<<"$out")"

{
  echo "plan-publish: source:   $src"
  echo "plan-publish: render:   $html"
  echo "plan-publish: feedback: plan-feedback $src"
} >&2

if [ "$status" = "user-ended" ]; then
  echo "plan-publish: the reviewer ended this session from the browser;" \
    "rerun with --reopen once they have confirmed another round" >&2
  exit 20
fi
