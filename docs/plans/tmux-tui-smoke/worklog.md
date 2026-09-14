# tmux for the TUI smoke - worklog

- 2026-09-13 [decision] Plan drafted as the exercise vehicle for the
  spawned-executor plan's item 2 (docs/plans/spawned-executor). Minimal
  by design; drafted by the orchestrator, approval pending.
- 2026-09-13 [decision] Plan approved by the human in session (inline
  review of the drafted docs; no design-review loop, minimal plan per
  the spawned-executor exercise). Status flipped to approved. Work runs
  on branch tmux-tui-smoke.
- 2026-09-13 [session] Item 1, executor seat, profile claude,
  invocation 1.
- 2026-09-13 [decision] Placement (plan decision 3): tool-adjacent in
  modules/home/common/pi.nix, next to nodejs. tmux exists here only so
  tests/pi-calm.test.sh can drive pi in a real TUI - that matches the
  nodejs precedent (dependency of the tool, not a base preference)
  better than the general CLI list in lib/base-packages.nix.
- 2026-09-13 [decision] Verification of "tmux -V" and the no-skip smoke
  ran against the built (not activated) generation: sudo needs a
  password this seat does not have, so the darwin switch could not run.
  Built darwinConfigurations.Abhis-MacBook-Pro.system from the machines
  repo with --override-input dotfiles pointing at this checkout, then
  prefixed PATH with the closure's home-manager-path/bin - byte-for-byte
  what /etc/profiles/per-user exposes after the human switches.
- 2026-09-13 [implemented] Added pkgs.tmux to home.packages in
  modules/home/common/pi.nix with a rationale comment; nodejs comment
  restructured into the list to keep one rationale per package. Sole
  declaration (git grep "tmux" over lib/, modules/, home.nix shows only
  pi.nix). Verified: tests/consumer-probe.test.sh exit 0 (both synthetic
  consumers build clean); darwin system builds with the change; tmux -V
  exit 0 (tmux 3.6a from the built profile, where pi resolves to the
  same pinned pi-coding-agent-0.85.1 store path as the live profile);
  bash tests/pi-calm.test.sh exit 0 with 7 ok lines and no "skip: pi or
  tmux not found" (the only skip is the pre-existing unrelated tsc one).
  Pending human: darwin-rebuild switch from the machines repo to land
  tmux on the live PATH, then commit.
- 2026-09-13 [session] Invocation 1: session id
  8e14bfa4-41c9-442a-aa6d-c4129accad78.
- 2026-09-13 [validation] Gate red for item 1 after invocation 1.
  Green: `git grep -n "tmux" -- 'lib/*.nix' 'modules/**' home.nix`
  (pi.nix declaration, sole hit); `bash tests/consumer-probe.test.sh`
  exit 0. Red: `tmux -V` -> `command not found: tmux`, exit 127, on the
  live PATH the validation line specifies (the built-closure PATH the
  invocation-1 entries describe is not the environment the line names).
- 2026-09-13 [session] Item 1, executor seat, profile claude,
  invocation 2 (resume: validation-red).
- 2026-09-13 [blocker] The red lines (`tmux -V` and the no-skip smoke on
  the live PATH) can only go green after the machine activates the new
  generation, and every honest route there is behind sudo, whose
  password this seat does not have (`sudo -n true` fails). Sudo-free
  alternatives were considered and rejected: activating the standalone
  homeConfiguration would fight the darwin-managed home (it omits
  devCheckout, so it aborts on or clobbers the live out-of-store
  authored links), and `nix profile install` would satisfy the letter
  from outside the exported configuration - a fake green. No files
  changed this invocation; the implementation from invocation 1 stands.
  Unblock: human runs the sudo switch from the machines repo. The
  generation is prebuilt with this checkout as the dotfiles input -
  `./result` there is current - so per the README pattern:
  `sudo ./result/sw/bin/darwin-rebuild switch --flake .#Abhis-MacBook-Pro
  --no-update-lock-file` (or rebuild after commit/merge if preferred).
  Then `tmux -V` and `bash tests/pi-calm.test.sh` on the live PATH
  should both go green; invocation 1 proved exactly that against this
  generation's home-manager-path.
- 2026-09-13 [session] Invocation 2: session id
  8e14bfa4-41c9-442a-aa6d-c4129accad78 (resumed, same session).
- 2026-09-13 [decision] Human resolved the invocation-2 blocker by doc
  repair: the breakdown's validation line was split - the PATH-dependent
  checks (`tmux -V`, the no-skip smoke) are now a `human:` line judged
  after the human's `darwin-rebuild switch` from the machines repo. The
  repo-side checks (grep, consumer probe) stay binding and are already
  green. Rationale: this library repo cannot activate a machine;
  demanding a live-PATH result from a seat inside it was a plan-doc
  gap, now repaired.
- 2026-09-13 [session] Item 1, executor seat, profile claude,
  invocation 3 (resume: steering).
- 2026-09-13 [implemented] No file changes this invocation; the
  invocation-1 implementation (pkgs.tmux in modules/home/common/pi.nix
  with rationale comment, sole declaration) stands. Re-verified the now
  binding lines fresh: `git grep -n "tmux" -- 'lib/*.nix' 'modules/**'
  home.nix` exit 0 (pi.nix only); `bash tests/consumer-probe.test.sh`
  exit 0 (all 10 ok lines, both synthetic consumers). Pending human:
  the repaired human: line - after `darwin-rebuild switch` from the
  machines repo, `tmux -V` exit 0 and the pi-calm smoke without the
  tmux skip (the prebuilt `./result` there is still current, per the
  invocation-2 blocker entry). Invocation 1 already proved both against
  that generation's home-manager-path.
- 2026-09-13 [session] Invocation 3: session id
  8e14bfa4-41c9-442a-aa6d-c4129accad78 (resumed, same session).
- 2026-09-13 [validation] Gate green for item 1 after invocation 3:
  `git grep -n "tmux" -- 'lib/*.nix' 'modules/**' home.nix` exit 0
  (pi.nix, sole declaration); `bash tests/consumer-probe.test.sh` exit
  0. The `human:` line (post-switch tmux -V and no-skip smoke) awaits
  the human. Proceeding to plan-item-review.
- 2026-09-13 [session] Item 1, reviewer seat, profile codex,
  invocation 1 (review-initial).
- 2026-09-13 [session] Reviewer invocation 1: thread id
  01a09e4b-c5f7-73e0-83d5-ed8d0cffa023.
- 2026-09-13 [done] Item 1 review loop closed at round 1: codex wrote a
  clean one-line verdict, no checklist items
  (item1_declare_tmux_review.md). Note: reviewer sandbox could not run
  the consumer probe (nix cache writes denied); the orchestrator gate
  had already run it green. Proceeding to the item conformance pass.
- 2026-09-13 [session] Item 1, conformance reviewer seat, profile
  codex, invocation 1 (fresh session).
- 2026-09-13 [session] Conformance invocation 1: thread id
  01a09e4d-0da3-7131-97b7-cb1f132ff250.
- 2026-09-13 [done] Item 1 conformance pass clean
  (item1_declare_tmux_conformance.md): sole declaration via the
  exported home configuration, rationale present, no scope drift. Same
  sandbox note as the review (nix cache writes denied; orchestrator
  gate evidence stands). Item status: reviewed, awaiting the human's
  switch + commit.
- 2026-09-13 [handoff] Synced: item 1 marked reviewed in breakdown.md.
  Remaining for the human: (a) `human:` validation - run
  `darwin-rebuild switch` from the machines repo (prebuilt `./result`
  current per the invocation-2 blocker entry), then confirm `tmux -V`
  and the no-skip pi-calm smoke on the live PATH; (b) commit the pi.nix
  change and these plan docs on branch tmux-tui-smoke. After the
  commit, flip item 1 to done <commit> and append the [done] entry. No
  plan artifact exists for this minimal plan (approved inline); publish
  one on request.
- 2026-09-13 [decision] Correction of record (spawned-executor item 2
  review, item 2): the two `[done]` entries above - "Item 1 review
  loop closed at round 1" and "Item 1 conformance pass clean" - used
  the wrong type. `[done]` means landed work (ARTIFACTS.md: commits,
  only an existing commit); no commit existed then or yet. Both
  entries are superseded as to type only - their content stands - and
  should be read as `[handoff]` milestones. History preserved
  append-only; future `[done]` entries are reserved for committed
  work.
- 2026-09-13 [validation] Human activation attempt 1 red: `tmux` still
  command-not-found after `darwin-rebuild switch` (generation of
  23:14). Cause: the machines repo's lock pins dotfiles at github rev
  3ae3836, and the invocation-2 blocker's suggested switch command
  omitted the `--override-input dotfiles` its own build used, so the
  switch faithfully rebuilt the old library without the tmux change.
  Corrected command given to the human: the same switch plus
  `--override-input dotfiles path:<checkout>`. Rough edge: unblock
  instructions must carry the full flag set of the build they
  reference.
- 2026-09-13 [validation] Human activation attempt 2 green (switch with
  the corrected override command): `tmux -V` -> tmux 3.6a on the live
  PATH; `bash tests/pi-calm.test.sh` exit 0, 7 ok lines, no "skip: pi
  or tmux not found" (only the pre-existing unrelated tsc skip). The
  item's `human:` validation line is satisfied; item 1 remains
  `reviewed` awaiting the human's commit.
- 2026-09-13 [done] Item 1 landed as 5b911d2 on branch tmux-tui-smoke.
  Verified: consumer probe green at the gate, review and conformance
  clean, tmux 3.6a live post-switch with the no-skip smoke green.
  Plan complete.
