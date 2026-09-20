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

    # Omarchy defines lsa as `ls -a`, which lands on the same view. ll is kept
    # as a second name for it because that is the muscle memory, not because
    # the listing differs.
    ll = "eza -lah --group-directories-first --icons=auto";

    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";

    # ── terraform ────────────────────────────────────────
    # The binary is not declared anywhere in this repo on purpose: terraform
    # state records the version that wrote it and refuses older ones, so the
    # version belongs to the project, in its mise.toml, not to the machine.
    ti = "terraform init";
    tp = "terraform plan";
    ta = "terraform apply";
    tv = "terraform validate";

    # ── odds and ends ────────────────────────────────────
    mkdir = "mkdir -p";
    path = "echo $PATH | tr -s ':' '\\n'";

    # ── docker ───────────────────────────────────────────
    # 36 aliases in the reference setup, cut to 8. Once `d` and `dc` exist,
    # `dps` is one keystroke better than `d ps` and `dstart` is one better than
    # `d start` -- the same reasoning that took 79 git aliases to 17. What
    # survives is what is typed constantly; the rest is reachable already.
    #
    # `d` duplicates Omarchy's own alias, identically. It is declared anyway,
    # because Omarchy's does not exist on macOS and this is what carries it.
    d = "docker";
    dc = "docker compose";
    dps = "docker ps";
    dpsa = "docker ps -a";
    dcu = "docker compose up";

    # The cleanup set keeps its names and loses its implementations. These were
    # `docker rm $(docker ps -a -q)` and friends, written before `prune` existed
    # -- Docker added it in 1.13, in 2017.
    #
    # The -a flags are not optional: `image prune` alone takes only dangling
    # images and `volume prune` alone takes only anonymous volumes, so without
    # them neither alias would resemble what it used to do.
    #
    # They now prompt before deleting, which the originals did not. That is an
    # improvement, not an oversight; add -f to skip it.
    #
    # One real change: `drmi` used to be `docker rmi -f`, which force-removed
    # images even while a container was using them. prune removes only what
    # nothing references. There is no prune equivalent for the old behaviour,
    # and forcing an image out from under a running container is a mess rather
    # than a cleanup.
    drmc = "docker container prune";
    drmi = "docker image prune -a";
    drmv = "docker volume prune -a";
    drma = "docker system prune -a --volumes";
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
