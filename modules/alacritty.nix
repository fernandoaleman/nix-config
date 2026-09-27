# Alacritty, from Omarchy's own config. The terminal is the load-bearing piece
# of cross-machine parity: it supplies the sixteen ANSI colours that starship
# and bat resolve against, so getting it the same is what makes those match for
# free.
#
# Alacritty rather than foot, which is Omarchy Quattro's default and the only
# terminal in omarchy-base.packages, because foot is Wayland-only and has no
# macOS build at all. Of the cross-platform options alacritty is also Omarchy's
# canonical palette source: omarchy-theme-colors-from-alacritty generates each
# theme's colors.toml *from* its alacritty.toml, so every Omarchy theme ships
# one and the other terminals derive from it.
#
# The one thing not shared is `general.import`, which names where the colours
# come from and necessarily differs per machine -- see hosts/beelink.
{
  programs.alacritty = {
    enable = true;

    # Almost nothing here on purpose.
    #
    # Omarchy's own alacritty.toml supplies the font, padding, decorations,
    # OSC 52 clipboard and the four CSI-u keybindings. hosts/beelink imports
    # that file *live*, so an omarchy update changes the terminal without this
    # repo being touched. Anything set here would win over it -- alacritty
    # loads imports first and the importing file last -- which is exactly the
    # drift worth avoiding, so only genuinely-ours settings belong here.
    #
    # ./alacritty/omarchy.toml is a snapshot of that file for the Mac, which
    # has no Omarchy to import from. `make omarchy-drift` reports when it has
    # fallen behind.
    settings = {
      # macOS-only, and inert on Linux -- alacritty parses it without
      # complaint, verified with migrate --dry-run and a real launch, so it
      # lives here rather than in the Mac host.
      #
      # It matters a great deal. Omarchy's tmux config binds 26 prefix-less
      # Alt combinations. On macOS, Option composes characters -- the key
      # gives e-acute rather than Alt -- and option_as_alt defaults to "None",
      # so every one of those bindings would silently do nothing there.
      #
      # "Both" rather than "OnlyLeft" because on Linux both Alt keys send Alt,
      # and matching that is the point.
      window.option_as_alt = "Both";
    };
  };
}
