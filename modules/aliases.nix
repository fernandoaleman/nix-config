# Shell aliases and the one function that has to stay a function, carried over
# from Omarchy's default/bash/aliases so the Mac behaves the same way.
#
# home.shellAliases is shell-agnostic: it feeds programs.bash today and would
# feed programs.zsh unchanged. On Omarchy these duplicate what Omarchy's own rc
# already defines, and win because modules/bash.nix sources that rc from
# bashrcExtra, which lands before home-manager's generated aliases. On the Mac
# they are the only source.
#
# Only the portable subset is here. Omarchy's `a` (omarchy-agent), `h` (herdr)
# and `ic`/`ix`/`icx` (its tdl tmux helpers) wrap tools that do not exist on
# macOS, and its `open()` wraps xdg-open, where macOS has a native `open` that
# must not be shadowed. Those stay in Omarchy's layer, unshared.
{
  # Installs eza but generates nothing: its integration would add ls/ll/la/lt
  # under its own names and flags, which are not Omarchy's. The aliases below
  # are the only ones, and they match Omarchy exactly.
  programs.eza = {
    enable = true;
    enableBashIntegration = false;
  };

  home.shellAliases = {
    # Omarchy's exact eza flags rather than programs.eza's defaults.
    ls = "eza -lh --group-directories-first --icons=auto";
    lsa = "ls -a";
    lt = "eza --tree --level=2 --long --icons --git";
    lta = "lt -a";

    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };

  # `zd` mutates the calling shell's directory, so unlike the rest of Omarchy's
  # helpers it cannot become a writeShellScriptBin derivation -- it has to be a
  # function in the shell. Taken verbatim from Omarchy's default/bash/aliases.
  programs.bash.initExtra = ''
    zd() {
      if (( $# == 0 )); then
        builtin cd ~ || return
      elif [[ -d $1 ]]; then
        builtin cd "$1" || return
      else
        if ! z "$@"; then
          echo "Error: Directory not found"
          return 1
        fi
        printf "\U000F17A9 "
        pwd
      fi
    }
    alias cd="zd"
  '';
}
