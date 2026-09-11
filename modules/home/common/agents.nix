{ config, ... }:

let
  agentsFile = config.lib.dotfiles.authored "home/AGENTS.md";
in
{
  # One AGENTS.md, fanned out to every agent that reads instructions.
  home.file.".claude/CLAUDE.md".source = agentsFile;
  home.file.".codex/AGENTS.md".source = agentsFile;
  home.file.".config/opencode/AGENTS.md".source = agentsFile;
}
