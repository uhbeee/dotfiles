{ config, ... }:

let
  authored = config.lib.dotfiles.authored;
in
{
  # The thinking family: three self-contained methods - grilling,
  # interview-me, writing-for-agents - in a family home at
  # ~/.config/thinking-skills, plus one thin adapter per skill per
  # agent CLI. No shared protocol, because the three share none: the
  # adapters assign the role and the per-CLI asking conventions and
  # point at the method file, so the links travel together.
  #
  # Whole-directory links, the same load-bearing rule plan-skills.nix
  # carries: codex discovers a skill whose directory is a symlink but
  # skips a real directory holding a per-file SKILL.md symlink, so a
  # per-file link here would silently produce no entry point. Common
  # module, no platform or profile gate - installed everywhere the
  # plan-* family is.
  home.file.".config/thinking-skills".source = authored "home/.config/thinking-skills";
  home.file.".claude/skills/grilling".source = authored "home/.claude/skills/grilling";
  home.file.".claude/skills/interview-me".source = authored "home/.claude/skills/interview-me";
  home.file.".claude/skills/writing-for-agents".source = authored "home/.claude/skills/writing-for-agents";
  home.file.".codex/skills/grilling".source = authored "home/.codex/skills/grilling";
  home.file.".codex/skills/interview-me".source = authored "home/.codex/skills/interview-me";
  home.file.".codex/skills/writing-for-agents".source = authored "home/.codex/skills/writing-for-agents";
}
