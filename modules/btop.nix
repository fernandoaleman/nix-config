# btop. Two settings, not a config file.
#
# Omarchy ships a 10KB btop.conf, and diffing it against the config btop
# generates itself shows it differs in exactly two places -- everything else is
# stock. So this declares the two and lets btop supply the rest, rather than
# carrying 280 lines of defaults that would silently drift from whatever btop
# ships next.
#
# `color_theme = "current"` is an indirection each machine satisfies its own
# way, which is what keeps the setting shareable:
#
#   Omarchy  ~/.config/btop/themes/current.theme is a symlink Omarchy manages,
#            pointing into ~/.local/state/omarchy/current/theme/btop.theme, so
#            btop follows the active Omarchy theme.
#   macOS    nothing provides it yet; the Mac host will need to, either via
#            programs.btop.themes.current or a theme file in this repo.
#
# programs.btop only writes themes it is explicitly given, so declaring
# `settings` alone leaves ~/.config/btop/themes/ untouched and Omarchy's
# symlink intact. Declaring `themes.current` here would replace that symlink
# with a static file and break Omarchy's theme switching.
#
# btop is also the one tool in the sweep whose theme is hex rather than named
# ANSI colours, so unlike starship and bat it does not follow the terminal
# palette for free. See plans/packages.md.
# One consequence of home-manager owning btop.conf: it is a read-only store
# symlink, so settings changed from inside btop's own UI cannot be written back
# and do not survive. Change them here instead. This is true of every managed
# config file, but btop is the first tool in this repo that offers in-app
# settings at all.
{
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "current";
      vim_keys = true;
    };
  };
}
