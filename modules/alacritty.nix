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

    settings = {
      env.TERM = "xterm-256color";
      terminal.osc52 = "CopyPaste";

      font = {
        normal = {
          family = "JetBrainsMono Nerd Font";
          style = "Regular";
        };
        bold = {
          family = "JetBrainsMono Nerd Font";
          style = "Bold";
        };
        italic = {
          family = "JetBrainsMono Nerd Font";
          style = "Italic";
        };
        # Sized for the Beelink's display. A retina Mac will almost certainly
        # want this larger -- the old setup used 20 there against 12 here -- so
        # expect the macOS host to override it rather than this to stay shared.
        size = 9;
      };

      window = {
        padding = {
          x = 14;
          y = 14;
        };
        # Hyprland draws no titlebar, so alacritty is told not to expect one.
        # macOS has no compositor doing that, and will want "buttonless".
        decorations = "None";
      };

      keyboard.bindings = [
        {
          key = "Insert";
          mods = "Shift";
          action = "Paste";
        }
        {
          key = "Insert";
          mods = "Control";
          action = "Copy";
        }
        # Shift+Return as CSI-u, so TUIs can tell it from Return without
        # reading it as Alt+Return. home-manager rewrites the literal \uXXXX
        # form into a real escape when it generates the TOML.
        {
          key = "Return";
          mods = "Shift";
          chars = "\\u001B[13;2u";
        }
        # Legacy encoding sends Alt+Shift+Return identically to Alt+Return;
        # CSI-u lets tmux match M-S-Enter.
        {
          key = "Return";
          mods = "Alt|Shift";
          chars = "\\u001B[13;4u";
        }
      ];
    };
  };
}
