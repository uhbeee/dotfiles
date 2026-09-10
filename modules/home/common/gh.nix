{ ... }:

{
  # gitCredentialHelper points git at `gh auth git-credential`, so `git push`
  # rides on the gh login rather than whatever osxkeychain happens to hold.
  # `gh auth login` still has to be run once per machine: the token is a
  # secret and never belongs in this repo.
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };
}
