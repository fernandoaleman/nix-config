# tmux, from Omarchy's config rather than the reference setup's.
#
# Two things decided this rather than habit. Omarchy's theme is written entirely
# in *named* colours -- blue, black, brightblack, default -- so it resolves
# against the terminal palette and matches on both machines for free, the same
# property that made starship and bat portable. The reference setup themed tmux
# with catppuccin-tmux, which is hex and would have undone that.
#
# And Omarchy's config sets `extended-keys on` with `extended-keys-format csi-u`,
# which is the receiving end of the four CSI-u keybindings in
# modules/alacritty.nix. They are a matched pair: Shift+Enter arriving at tmux
# as distinct from Enter only works because both halves agree.
#
# Dropped from the reference setup: catppuccin-tmux (hex, see above), tpm
# (programs.tmux.plugins installs from nixpkgs, so the bootstrap script goes
# too), and `default-shell /usr/bin/zsh`, which is obsolete -- see shell.md.
{ ... }:

{
  programs.tmux = {
    enable = true;

    # tmux-sensible would load first and set overlapping defaults. Omarchy's
    # config is complete and opinionated, so there is nothing for it to add and
    # a real chance of it quietly disagreeing.
    sensibleOnTop = false;

    # Not a preference: clock24 defaults to false and is emitted unconditionally
    # even when unset, so leaving it alone writes `clock-mode-style 12`. Omarchy
    # sets nothing and inherits tmux's 24-hour default, so matching it means
    # saying so explicitly.
    clock24 = true;

    # Omarchy's tmux.conf, whole, with only history-limit changed.
    #
    # Deliberately not using programs.tmux's prefix/keyMode/clock24/etc.
    # options, convenient as they look. Each bundles more than the single line
    # it appears to replace, and all three tried here changed behaviour that
    # Omarchy had left alone:
    #
    #   prefix    emits `unbind C-b` first, destroying tmux's default
    #             `C-b send-prefix` -- which Omarchy relies on, since it keeps
    #             C-b as prefix2.
    #   keyMode   sets status-keys as well as mode-keys, moving the command
    #             prompt from emacs editing to vi. Omarchy sets only mode-keys.
    #   clock24   defaults to false, flipping the clock to 12-hour where
    #             Omarchy inherits tmux's 24-hour default.
    #
    # Each was caught by diffing `list-keys` and `show-options` against a tmux
    # server started on Omarchy's own config. The generated file now matches it
    # binding for binding and option for option, history-limit aside.
    extraConfig = builtins.readFile ./tmux/omarchy.conf;
  };

  # tdl / tds / tdlm / tsl. See the file for why these are functions.
  programs.bash.initExtra = builtins.readFile ./tmux/dev-layouts.bash;
}
