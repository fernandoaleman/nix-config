# Omarchy-specific shell glue. Linux only, by definition -- none of this exists
# on macOS, which is exactly why it is a host file rather than a shared module.
{
  # Alacritty's colours come from Omarchy's live theme state, so switching
  # themes with omarchy-theme-set restyles the terminal as it always did. This
  # is the one line of modules/alacritty.nix that cannot be shared: the path
  # does not exist on macOS, where the Mac host will point at a palette kept in
  # this repo instead.
  programs.alacritty.settings.general.import = [
    "~/.local/state/omarchy/current/theme/alacritty.toml"
  ];

  # Make alacritty the terminal Omarchy actually opens. omarchy-launch-terminal
  # execs xdg-terminal-exec, which reads the first matching
  # <desktop>-xdg-terminals.list it finds; with XDG_CURRENT_DESKTOP=Hyprland
  # this file outranks /usr/share/xdg-terminal-exec/hyprland-xdg-terminals.list,
  # which omarchy-settings ships naming foot.desktop. foot is listed second so
  # it stays a working fallback.
  #
  # Note the path: xdg-terminal-exec looks for the bare filename under the
  # *config* dirs and only uses an `xdg-terminal-exec/` subdirectory under the
  # *data* dirs. Putting it in ~/.config/xdg-terminal-exec/ silently does
  # nothing -- confirmed with XTE_DEBUG=1, which prints the search list.
  #
  # It also caches its decision in ~/.cache/xdg-terminal-exec keyed on a hash
  # of the config and data paths, so a stale cache can mask a correct change.
  #
  # Safe for home-manager to own: the path is not in
  # always_copy_config_files and no migration writes to it.
  xdg.configFile."hyprland-xdg-terminals.list".text = ''
    # Managed by nix-config. Alacritty is configured in modules/alacritty.nix.
    Alacritty.desktop
    foot.desktop
  '';

  programs.bash = {
    # home-manager writes ~/.bashrc and ~/.profile, replacing the skel-seeded
    # ~/.bashrc outright. Omarchy's entire interactive layer -- 28 aliases, 22
    # functions across 8 files, its inputrc, and the mise/starship/zoxide/fzf
    # init -- hangs off two source lines in that file. Re-declared here, or it
    # all disappears with nothing to indicate it ever existed.
    #
    # bashrcExtra rather than initExtra, for two reasons. It lands *above*
    # home-manager's `[[ $- == *i* ]] || return`, which is where env-bootstrap
    # has to be: OMARCHY_PATH is wanted in non-interactive shells too, which is
    # why Omarchy puts it above its own guard. And it lands *before*
    # home-manager's generated aliases, so anything declared in
    # home.shellAliases wins over Omarchy's on a name collision, rather than
    # being silently overridden by a file this repo does not control.
    bashrcExtra = ''
      # OMARCHY_PATH and the user-level PATH additions. Wanted in
      # non-interactive shells too, so it sits above the interactive guard.
      [[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] &&
        source /usr/share/omarchy/default/bash/env-bootstrap

      # Omarchy's aliases, functions, completions and inputrc.
      if [[ $- == *i* ]] && [[ -r "$OMARCHY_PATH/default/bash/rc" ]]; then
        source "$OMARCHY_PATH/default/bash/rc"
      fi
    '';

  };
}
