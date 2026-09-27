# The prompt. Omarchy's starship.toml, carried over so the Mac gets the same
# prompt rather than starship's default.
#
# It ports cleanly because every colour in it is a *named* ANSI colour --
# "bold cyan", "italic cyan" -- which resolves against the terminal's palette
# rather than a hardcoded hex value. Nothing here refers to Omarchy's theme
# state, so the same file produces the same prompt on both machines as long as
# the terminals agree on their sixteen colours.
{
  programs.starship = {
    enable = true;
    enableBashIntegration = true;

    # settings is deliberately empty. programs.starship only writes
    # ~/.config/starship.toml when settings or presets are non-empty
    # (hasGeneratedConfig in the module), so leaving it empty hands that path
    # to the host -- which on Linux symlinks Omarchy's own file, live, so an
    # omarchy update restyles the prompt without this repo being touched.
    #
    # STARSHIP_CONFIG is still exported, pointing at the same path, so the
    # arrangement is invisible to starship.
    #
    # ./starship/omarchy.toml is a snapshot of Omarchy's prompt for the Mac,
    # which has no Omarchy to point at. `make omarchy-drift` reports when it
    # has fallen behind.
    #
    # Worth recording why the snapshot is a file rather than a Nix attrset:
    # Omarchy's prompt carries Nerd Font glyphs in the private use area --
    # U+EBAB, U+F00C, U+EA71 for the conflicted, up-to-date and modified git
    # states. They render as nothing without that font, and transcribing the
    # file by eye silently dropped all three.
    settings = { };
  };
}
