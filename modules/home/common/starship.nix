{ lib, ... }:

{
  # This is the starship tool that helps customize the prompt on the terminal: all the stuff printed out before the cursor on the terminal. This modifies that!
  programs.starship = {
    enable = true;
    # Every leaf is mkDefault so a machine overrides one setting by plain
    # assignment while inheriting the rest.
    settings = {
      add_newline = lib.mkDefault false;
      format = lib.mkDefault "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = lib.mkDefault "[❯](purple)";
        error_symbol = lib.mkDefault "[❯](red)";
      };
      cmd_duration.format = lib.mkDefault "[$duration]($style) ";
    };
  };
}
