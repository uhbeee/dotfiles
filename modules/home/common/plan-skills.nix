{ config, pkgs, ... }:

let
  authored = config.lib.dotfiles.authored;
in
{
  # The plan-* family: a harness-neutral core (PROTOCOL.md, ROLES.md,
  # ARTIFACTS.md) plus one thin adapter per skill per agent CLI, so any
  # machine can orchestrate from either claude or codex. The adapters
  # reference the core at ~/.config/plan-skills, so the links travel
  # together.
  #
  # Both CLIs take the adapter as a skill directory, and each is linked
  # as a whole directory on purpose: codex discovers a skill whose
  # directory is a symlink, but skips a real directory holding a
  # per-file SKILL.md symlink (verified on codex-cli 0.153.4), so
  # per-file links here would silently produce no entry points.

  # The review surface's tools ride with the skills that need them (cf.
  # pi.nix's nodejs), not in the exported base list: pandoc renders plan
  # markdown to standalone HTML, lavish-axi serves it for browser
  # annotation, and pkgs/plan-publish wraps the two as the plan-publish
  # and plan-feedback commands every orchestrator invokes identically.
  # Common module, no platform gate - installed everywhere the skills
  # are (darwin, Linux, WSL). lavish-axi is pinned and built from the
  # npm tarball in pkgs/lavish-axi.
  home.packages =
    let
      lavish-axi = pkgs.callPackage ../../../pkgs/lavish-axi { };
    in
    [
      pkgs.pandoc
      lavish-axi
      (pkgs.callPackage ../../../pkgs/plan-publish { inherit lavish-axi; })
    ];
  home.file.".config/plan-skills".source = authored "home/.config/plan-skills";
  home.file.".claude/skills/plan-create".source = authored "home/.claude/skills/plan-create";
  home.file.".claude/skills/plan-implement".source = authored "home/.claude/skills/plan-implement";
  home.file.".claude/skills/plan-item-review".source = authored "home/.claude/skills/plan-item-review";
  home.file.".claude/skills/plan-sync".source = authored "home/.claude/skills/plan-sync";
  home.file.".claude/skills/plan-conformance-pass".source = authored "home/.claude/skills/plan-conformance-pass";
  home.file.".claude/skills/plan-archive".source = authored "home/.claude/skills/plan-archive";
  home.file.".codex/skills/plan-create".source = authored "home/.codex/skills/plan-create";
  home.file.".codex/skills/plan-implement".source = authored "home/.codex/skills/plan-implement";
  home.file.".codex/skills/plan-item-review".source = authored "home/.codex/skills/plan-item-review";
  home.file.".codex/skills/plan-sync".source = authored "home/.codex/skills/plan-sync";
  home.file.".codex/skills/plan-conformance-pass".source = authored "home/.codex/skills/plan-conformance-pass";
  home.file.".codex/skills/plan-archive".source = authored "home/.codex/skills/plan-archive";
}
