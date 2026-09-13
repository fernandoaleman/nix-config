# bash as the interactive shell -- the portable half. Everything here applies
# on macOS unchanged.
#
# The Omarchy-specific glue that keeps its shell layer alive lives in
# hosts/beelink/omarchy.nix, because it has no macOS equivalent and leaning on
# it is a decision to diverge. See plans/shell.md for why bash rather than zsh.
{
  programs.bash = {
    enable = true;

    # Omarchy's default/bash/shell sets HISTSIZE=32768 and
    # HISTCONTROL=ignoreboth. These land after it and win. The reference zsh
    # setup kept a million lines and there is no reason to keep less.
    historySize = 1000000;
    historyFileSize = 1000000;
    historyControl = [
      "ignoredups"
      "ignorespace"
      "erasedups"
    ];

    # home-manager's defaults plus histverify, which is bash's spelling of the
    # reference setup's `setopt hist_verify`: expand a `!!` onto the command
    # line for review instead of running it straight away.
    shellOptions = [
      "histappend"
      "histverify"
      "checkwinsize"
      "extglob"
      "globstar"
      "checkjobs"
    ];
  };
}
