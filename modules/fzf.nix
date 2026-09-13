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

    # Omarchy sets neither of these, so both were simply missing. Carried over
    # from the reference setup's conf.d/30-fzf.zsh, where they were the only
    # lines not concerned with locating Homebrew's copy of fzf.
    defaultCommand = "rg --files --hidden --follow --glob '!.git/*'";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
    ];
  };
}
