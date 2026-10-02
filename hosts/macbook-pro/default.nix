# MacBook Pro (Apple Silicon) -- standalone home-manager, no nix-darwin.
#
# nix-darwin writes /etc/bashrc and friends and manages system defaults. None
# of that is needed to test whether the shared modules port, and standalone
# home-manager is trivially reversible, so it comes first. nix-darwin earns its
# place when macOS system defaults are wanted -- a later section.
#
# Everything here is an override that exists *because* there is no Omarchy.
# The count is the experiment: if this file stays small, the shared modules are
# doing real work. See plans/macos.md.
{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    # Note what is absent: ./omarchy.nix. Every other module is shared
    # verbatim with the Beelink.
    ../../modules/alacritty.nix
    ../../modules/aliases.nix
    ../../modules/bash.nix
    ../../modules/bat.nix
    ../../modules/btop.nix
    ../../modules/fzf.nix
    ../../modules/git.nix
    ../../modules/mise.nix
    ../../modules/packages.nix
    ../../modules/starship.nix
    ../../modules/tmux.nix
    ../../modules/try.nix
  ];

  home.username = "faleman";
  home.homeDirectory = "/Users/faleman";
  home.stateVersion = "26.05";
  xdg.enable = true;
  programs.home-manager.enable = true;

  # ── 1. alacritty: snapshots instead of Omarchy's live files ──────────
  # On Linux these are imported from /usr/share/omarchy and ~/.local/state, so
  # an omarchy update flows through. Here they are copies, frozen on purpose:
  # the Mac has no omarchy-theme-set to follow. `make omarchy-drift` reports
  # when the base config has fallen behind.
  xdg.configFile."alacritty/omarchy.toml".source = ../../modules/alacritty/omarchy.toml;
  xdg.configFile."alacritty/omarchy-theme.toml".source = ../../modules/alacritty/omarchy-theme.toml;

  programs.alacritty.settings = {
    general.import = [
      "~/.config/alacritty/omarchy.toml"
      "~/.config/alacritty/omarchy-theme.toml"
    ];

    # ── 2. a retina display wants more than the Beelink's 9 ──────────
    font.size = lib.mkForce 14;

    # ── 3. macOS draws its own titlebar; Hyprland does not ───────────
    # "None" removes it entirely, which on macOS loses the traffic lights.
    window.decorations = lib.mkForce "buttonless";
  };

  # ── 4. starship: the snapshot, since there is no Omarchy to symlink ──
  xdg.configFile."starship.toml".source = ../../modules/starship/omarchy.toml;

  # ── 5. tmux: source the snapshot, then drop the Omarchy-only binding ──
  # `?` shells out to omarchy-menu-tmux-keybindings, which does not exist here.
  programs.tmux.extraConfig = lib.mkBefore ''
    source-file ${../../modules/tmux/omarchy.conf}
    unbind ?
  '';

  # ── 6. btop: no Omarchy theme state to point `current` at ────────────
  programs.btop.settings.color_theme = lib.mkForce "Default";

  # ── 7. coreutils, for GNU behaviour over BSD ─────────────────────────
  # Exists to undo a difference Linux does not have.
  #
  # ── 8. the font the terminal config asks for ─────────────────────────
  # Omarchy installs JetBrainsMono Nerd Font system-wide on Linux, so
  # modules/alacritty.nix can simply name it. macOS supplies nothing, and the
  # font was absent from all three font directories -- alacritty would have
  # fallen back to a default, and the Nerd Font glyphs in Omarchy's starship
  # prompt (U+EBAB, U+F00C, U+EA71 for the git states) would have rendered as
  # empty boxes.
  #
  # home-manager links fonts into ~/Library/Fonts on darwin, which is why the
  # generation carries .home-manager-fonts-version there.
  home.packages = [
    pkgs.coreutils
    pkgs.nerd-fonts.jetbrains-mono
  ];
}
