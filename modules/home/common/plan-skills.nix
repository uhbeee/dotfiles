{ config, ... }:

let
  authored = config.lib.dotfiles.authored;
in
{
  # The plan-* review loop: a harness-neutral protocol (PROTOCOL.md,
  # ROLES.md) plus one thin adapter per agent CLI, so any machine can
  # orchestrate the loop from either claude or codex. The adapters
  # reference the protocol at ~/.config/plan-skills, so the three links
  # travel together.
  home.file.".config/plan-skills".source = authored "home/.config/plan-skills";
  home.file.".claude/skills/plan-review".source = authored "home/.claude/skills/plan-review";
  home.file.".claude/skills/plan-conformance-pass".source = authored "home/.claude/skills/plan-conformance-pass";
  home.file.".codex/prompts/plan-review.md".source = authored "home/.codex/prompts/plan-review.md";
  home.file.".codex/prompts/plan-conformance-pass.md".source = authored "home/.codex/prompts/plan-conformance-pass.md";
}
