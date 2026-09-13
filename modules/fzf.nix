# fzf, with home-manager owning the shell integration.
#
# Omarchy's rc sources /usr/share/fzf/key-bindings.bash, which pacman owns.
# Once Nix supplies the fzf *binary*, Ctrl-R depends on a pacman package that
# is no longer the one providing the tool -- so removing that package as an
# apparent duplicate would silently break it: the `command -v fzf` guard in
# Omarchy's init still passes, because Nix's fzf answers it, and the `source`
# then finds nothing.
#
# programs.fzf fixes that by emitting `eval "$(fzf --bash)"` from the Nix
# store, with no reference to /usr/share. It lands in programs.bash.initExtra
# at mkOrder 200, which is after modules/bash.nix sources Omarchy's rc from
# bashrcExtra, so these bindings are the ones that end up installed.
#
# Omarchy's own fzf lines still run first when pacman's fzf is present. There
# is no supported way to suppress them -- its shell layer has no opt-out, and
# its hooks are for system events, not shell init -- so the cost is one
# redundant source per interactive shell, in exchange for a Ctrl-R that no
# longer depends on a package this repository does not manage.
{
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;

    # No defaultCommand and no defaultOptions, deliberately.
    #
    # The reference setup set FZF_DEFAULT_COMMAND to
    # `rg --files --hidden --follow --glob '!.git/*'`. Three of those four
    # behaviours are now fzf's own defaults -- `fzf --help` gives
    # `--walker=file,follow,hidden` and `--walker-skip=.git,node_modules` --
    # because fzf grew a built-in walker in 0.44, years after that line was
    # written. The only remaining difference is that ripgrep honours
    # .gitignore and fzf's walker does not, which is not worth a setting.
    #
    # FZF_DEFAULT_OPTS is worse than redundant: it applies to *every* fzf
    # invocation, including Omarchy's `ff` alias, which is a previewer that
    # renders images inline through `kitty icat`. Forcing `--height 40%` on it
    # shrinks that preview to a fraction of the terminal. If an inline height
    # is ever wanted for the widgets specifically, FZF_CTRL_T_OPTS and
    # FZF_CTRL_R_OPTS are the mechanism that leaves `ff` alone.
  };
}
