{ lib, ... }:

{
  # mkDefault: a library preference, not a mandate. A consumer's plain
  # assignment wins without ceremony.
  home.sessionVariables.EDITOR = lib.mkDefault "nvim";
}
