# One machine, one file. This repo is the only place identity ever appears;
# the library stays user and device agnostic. Copy this file per machine and
# answer its questions; nothing else belongs here.
{
  user = "alice";
  host = "alices-mac";                  # names the flake output for this machine
  system = "aarch64-darwin";            # or x86_64-darwin, x86_64-linux, aarch64-linux
  homeDirectory = "/Users/alice";       # /home/alice on Linux
  # "full" is everything; "cli" drops the GUI-adjacent config (terminal
  # emulator and friends) - the right answer for servers and containers.
  profile = "full";
  # The home-manager release that first managed this machine. Set it at
  # install time and never change it; it is a data-migration baseline, not a
  # version to keep current. Never copy another machine's value.
  stateVersion = "25.05";
}
