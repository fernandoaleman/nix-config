# Omarchy-specific shell glue. Linux only, by definition -- none of this exists
# on macOS, which is exactly why it is a host file rather than a shared module.
{
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
