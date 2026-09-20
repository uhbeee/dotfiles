{ lib
, symlinkJoin
, writeShellApplication
, coreutils
, gnugrep
, gawk
, jq
, lsof
, unixtools
, pandoc
, lavish-axi
}:

# The plan-* review surface's publish wrapper: plan-publish renders a
# markdown file (pandoc, gfm) into a cache directory keyed by the
# source's canonical absolute path and opens/refreshes it as a
# lavish-axi session; plan-feedback is the bounded-wait poll with
# distinguishable outcomes (feedback / timeout / session unavailable /
# ended / disconnected) encoded as exit codes, persisting every polled
# payload to the session's feedback.log before returning it. The full
# contract, including crash recovery, is in each command's --help.
# Orchestrator-agnostic on purpose: plain executables, no harness
# dependency, identical from claude and codex seats.
let
  # unixtools.ps is the platform-appropriate ps (procps-family on
  # Linux, Apple's on darwin) for plan-feedback's process inspection.
  runtimeInputs = [ coreutils gnugrep gawk jq lsof unixtools.ps pandoc lavish-axi ];

  plan-publish = writeShellApplication {
    name = "plan-publish";
    inherit runtimeInputs;
    text = builtins.readFile ./plan-publish.sh;
  };

  plan-feedback = writeShellApplication {
    name = "plan-feedback";
    inherit runtimeInputs;
    text = builtins.readFile ./plan-feedback.sh;
  };
in
symlinkJoin {
  name = "plan-publish";
  paths = [ plan-publish plan-feedback ];
  meta = {
    description = "Publish wrapper and feedback poll for the plan-* review surface (pandoc + lavish-axi)";
    platforms = lib.platforms.all;
  };
}
