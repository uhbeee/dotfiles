{ config, ... }:

let
  authored = config.lib.dotfiles.authored;
in
{
  # The plan-* family: a harness-neutral core (PROTOCOL.md, ROLES.md,
  # ARTIFACTS.md) plus one thin adapter per skill per agent CLI, so any
  # machine can orchestrate from either claude or codex. The adapters
  # reference the core at ~/.config/plan-skills, so the links travel
  # together.
  home.file.".config/plan-skills".source = authored "home/.config/plan-skills";
  home.file.".claude/skills/plan-create".source = authored "home/.claude/skills/plan-create";
  home.file.".claude/skills/plan-implement".source = authored "home/.claude/skills/plan-implement";
  home.file.".claude/skills/plan-item-review".source = authored "home/.claude/skills/plan-item-review";
  home.file.".claude/skills/plan-sync".source = authored "home/.claude/skills/plan-sync";
  home.file.".claude/skills/plan-conformance-pass".source = authored "home/.claude/skills/plan-conformance-pass";
  home.file.".claude/skills/plan-archive".source = authored "home/.claude/skills/plan-archive";
  home.file.".codex/prompts/plan-create.md".source = authored "home/.codex/prompts/plan-create.md";
  home.file.".codex/prompts/plan-implement.md".source = authored "home/.codex/prompts/plan-implement.md";
  home.file.".codex/prompts/plan-item-review.md".source = authored "home/.codex/prompts/plan-item-review.md";
  home.file.".codex/prompts/plan-sync.md".source = authored "home/.codex/prompts/plan-sync.md";
  home.file.".codex/prompts/plan-conformance-pass.md".source = authored "home/.codex/prompts/plan-conformance-pass.md";
  home.file.".codex/prompts/plan-archive.md".source = authored "home/.codex/prompts/plan-archive.md";
}
