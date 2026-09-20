# bat, and bat-as-manpager. Both carried over from Omarchy's default/bash/envs
# so the Mac gets the same behaviour; neither is Linux-specific.
#
# theme = "ansi" is the portable choice and Omarchy's own: it tells bat to use
# the terminal's sixteen ANSI colours rather than shipping its own palette, so
# bat follows whatever the terminal is themed as on either machine.
{
  programs.bat = {
    enable = true;
    config.theme = "ansi";
  };

  home.sessionVariables = {
    # Render man pages through bat. MANROFFOPT=-c stops groff emitting
    # overstrike sequences that `col -b` would otherwise mangle.
    MANROFFOPT = "-c";
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
  };
}
