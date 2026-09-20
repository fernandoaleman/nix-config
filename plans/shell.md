# Plan: shell — bash now, zsh deferred

Revision 1. Depends on [`foundation.md`](foundation.md). Supersedes the shell *choice* in [`zsh.md`](zsh.md), which stays as the deferred implementation plan.

## Problem

The reference setup is 26 files of zsh, and the stated reason for keeping zsh was that it is the default on macOS. Two things discovered while verifying foundation.md undermine that:

- **Omarchy Quattro is bash-first, with a substantial shell layer.** `/usr/share/omarchy/default/` contains `bash/` and `bashrc` and nothing zsh — no zsh support anywhere in the tree. That layer is 28 aliases, **22 functions across 8 files** (`compress`, `iso2sd`, `format-drive`, the herdr set, rsync wrappers, ssh port-forwarding, ssh-reconnect, the tmux set, and the `ga`/`gd` worktree helpers), an inputrc loaded via `bind -f`, session variables, and the mise/starship/zoxide/fzf init. It is bash — `shopt`, `bind -f`, `complete -`, `BASH_COMPLETION_VERSINFO` — so zsh cannot source it.
- **"zsh is the macOS default" does not survive contact with Nix.** The shell comes from the flake on both machines, not from the OS. All the default buys is skipping `chsh`, and that is symmetrical: zsh needs `chsh` on Omarchy, bash needs it on macOS.

## Rejected approaches

- **zsh now.** Deferred rather than rejected — see below. The blocker was never the config, it was that adopting zsh means reimplementing Omarchy's 22 functions before the machine is as capable as it was out of the box.
- **`ble.sh` to get syntax highlighting under bash.** In nixpkgs (0.4.0-devel3) but has no home-manager module, and it is a *complete replacement for readline*, not a plugin: it supersedes Omarchy's carefully-tuned inputrc and needs its own fzf integration rather than the stock `key-bindings.bash` Omarchy sources. That trades away `Ctrl-R`, which is used daily, to gain highlighting, which is not wanted. Bad deal.
- **Splitting shells per machine** — bash on Omarchy, zsh on the Mac. Directly against the repository's one-shared-layer thesis, and doubles the surface for no gain.
- **Leaving the shell entirely unmanaged.** Tempting as the true zero-work option, but `home.sessionVariables` and `home.shellAliases` only reach an interactive shell through `programs.bash` or `programs.zsh` sourcing `hm-session-vars.sh` (`modules/programs/bash.nix:269`, `zsh/default.nix:426`). With neither enabled, home-manager cannot configure the shell at all, and every CLI tool's shell integration is unavailable. Deferring that way would mean doing the same work later having gained nothing.

## Chosen design

**bash, with a deliberately thin `modules/bash.nix`.** Its main job is to not destroy what Omarchy already provides.

home-manager writes `~/.bashrc` and `~/.profile` outright, and Omarchy's whole interactive layer hangs off two `source` lines in the file it replaces. Those lines are re-declared in `bashrcExtra`, not `initExtra`, for two reasons that both come from the generated file's structure:

```
${bashrcExtra}
[[ $- == *i* ]] || return      <- home-manager's interactive guard
${historyControl} ${shopts} ${aliases} ${initExtra}
```

`bashrcExtra` lands *above* the guard, which is where `env-bootstrap` has to be — `OMARCHY_PATH` is wanted in non-interactive shells too, which is why Omarchy puts it above its own guard. And it lands *before* home-manager's generated aliases, so anything in `home.shellAliases` wins a name collision rather than being silently overridden by a file this repository does not control.

Everything expensive is therefore shell-neutral: aliases in `home.shellAliases`, variables in `home.sessionVariables`, non-state-mutating functions as `pkgs.writeShellScriptBin` derivations per zsh.md's own rule. If zsh is adopted later, none of that content moves — only the thin wrapper is replaced.

### What choosing bash actually costs

Assessed by reading all 26 files of the reference zsh config rather than from the plan's summary. Most of it was never shell-dependent:

| Loses | Severity |
|---|---|
| zsh-autosuggestions — inline grey prediction from history, accepted with one keystroke | **None in practice.** `Ctrl-R` (fzf) and `Ctrl-P` are preferred, and were already what got used |
| zsh-syntax-highlighting | Not wanted; `ble.sh` rejected above |
| zsh's completion system — menu select, descriptions, `_files -W` | Moderate, and reduced: the largest investment here was the `compdef _git gst=git-stash` family, already eliminated by moving aliases to `programs.git.settings.alias` |
| `accept-and-hold` (`^Y`) | Real, trivial. No readline equivalent |
| `autopushd` and the directory stack | Moot — Omarchy aliases `cd` to `zd` and zoxide supersedes it |
| `hist_expire_dups_first` | Trivial |

No global aliases (`alias -g`) or suffix aliases (`alias -s`) were in use — the two zsh features with no bash answer at all. What transfers exactly: `autocd`→`shopt -s autocd`, `hist_verify`→`histverify`, `nomatch`→bash's default, recursive globs→`globstar`, `bindkey -v`→`set -o vi`, and `^A`/`^E`/`^K`/`history-search-backward` are readline function names already. Omarchy's inputrc even binds the arrow keys to prefix search, which is what `20-keybindings.zsh` hand-configured.

### macOS

Checked against nix-darwin's source. Only one difference is genuinely macOS-shaped: nix-darwin generates `/etc/zshenv`, `/etc/zprofile` and `/etc/zshrc` for zsh but only `/etc/bashrc` for bash, and never touches `/etc/profile`. `/etc/zshenv` is read by *every* zsh invocation, so non-interactive non-login zsh gets the nix environment and the bash equivalent does not — which bites `bash -c` from GUI apps, launchd jobs and some IDE build steps.

Two fears that turn out unfounded: nix-darwin's `/etc/bashrc` opens with `[ -r "/etc/bashrc_$TERM_PROGRAM" ] && . "/etc/bashrc_$TERM_PROGRAM"`, so Terminal.app session restore and working-directory tracking are explicitly preserved; and `path_helper` is no worse under bash, since Apple's `/etc/profile` runs it before sourcing `/etc/bashrc`, which then re-applies the nix environment. Apple's bash is 3.2.57 from 2007, but nix-darwin's `programs.bash` installs `pkgs.bashInteractive` and defaults to enabled.

All of that is moot under standalone home-manager, which writes none of those `/etc` files — see foundation.md open question 3.

## The alias trim

The reference setup had 137 aliases. 79 were git and became 17 git subcommands in [`git.md`](git.md); the other 58 are covered here and became 12. Omarchy's own portable set — `ls`, `lsa`, `lt`, `lta` and the `..`/`...`/`....` chain — is carried alongside them in `modules/aliases.nix`, so the shared file declares 19 in total.

### docker: 36 → 9

Docker was 36 of the 58 on its own. The cut follows the same reasoning that took the git aliases down: once `d` and `dc` exist, everything else is reachable through them, and most of the rest saved two to four keystrokes over `d ps` or `dc up`. Six saved exactly one — `dstart` over `d start`.

Kept: `d`, `dc`, `dps`, `dpsa`, `dcu`, plus the cleanup set below. `d` duplicates Omarchy's own alias identically and is declared anyway, because Omarchy's does not exist on macOS.

The compose set could be cut harder than the git set because day-to-day compose work happens in lazydocker rather than the CLI.

**The cleanup trio kept its names and lost its implementations.** They were `docker rm $(docker ps -a -q)`, `docker rmi -f $(docker images -q)` and `docker volume rm $(docker volume ls -q)` — written before `prune` existed, which Docker added in 1.13, in 2017. The same shape as the fzf walker: a workaround for something upstream fixed years ago.

```
drmc = docker container prune
drmi = docker image prune -a
drmv = docker volume prune -a
drma = docker system prune -a --volumes
```

The `-a` flags are not optional. `image prune` alone takes only *dangling* images and `volume prune` alone takes only *anonymous* volumes, so without them neither alias would resemble what it used to do. They also now prompt before deleting, which the originals did not — an improvement, and `-f` skips it.

One real behaviour change: `drmi` was `docker rmi -f`, which force-removed images even while a container was using them. `prune` removes only what nothing references, and there is no prune equivalent for the old behaviour. Forcing an image out from under a running container is a mess rather than a cleanup.

### The other 22 → 3

Kept: `ll`, `mkdir = "mkdir -p"`, and `path`. Everything else went, for reasons that were mostly structural rather than taste:

| Dropped | Why |
|---|---|
| `ls = "eza --icons=always"` | Omarchy's is strictly richer and already declared. Parity rule: Omarchy's wins |
| `be = "noglob bundle exec"` | **`noglob` is a zsh builtin.** It does not exist in bash and would have failed outright |
| `top = "btm"` | `btm` is not installed — the alias pointed at nothing |
| `ag = "ag -uf --hidden"` | silver-searcher is not installed; ripgrep replaced it |
| `chez = "chezmoi"` | Dead. chezmoi is what this repository replaces |
| `b`, `bu`, `s`, `migrate` | Rails work now happens through Claude Code and Codex rather than at the shell |
| `ta`, `ti`, `tp`, `tv` | terraform is still used, but is not installed here and gets its own discussion |
| `cp = "cp -iv"`, `mv = "mv -iv"`, `cat = "bat"` | Considered and declined. Omarchy defines none of `cp`, `mv`, `mkdir`, `cat`, `ln` — they are plain coreutils binaries — so there was no conflict to resolve, only a preference, and the preference was to leave POSIX tools alone |
| `ln = "ln -v"`, `e = "$EDITOR"`, `v = "$VISUAL"` | Never used |

`mkdir` kept `-p` but dropped `-v`. `ll` is a second name for the view `lsa` already gives; it is there for the muscle memory, not because the listing differs.

Worth recording that **12 of those 22 pointed at tools not installed on this machine** — terraform, bundler, rspec, rake, silver-searcher, bottom, chezmoi. Not an argument to drop them on its own, but it does mean none had been typed since the machine was built.

## Open questions

1. **Revisit zsh when?** Nothing forces a decision. The cheap experiment is already running: this machine has been on bash since 2026-08-30. If something turns out to be missed, `zsh.md` is still accurate and the content in `home.shellAliases`/`home.sessionVariables` carries over untouched.
2. **Omarchy already runs `starship init bash`, `mise activate bash`, `zoxide init bash` and sources fzf's key bindings from its own rc.** Enabling `programs.starship`/`programs.zoxide`/`programs.fzf` would add a *second* init to `initExtra`. Needs resolving in the packages module — either let Omarchy do it and take only the packages from Nix, or suppress the integration on one side.
3. **The login shell is `/usr/bin/bash` while `programs.bash` puts nix's bash on PATH.** So an interactive `bash` is nix's and the login shell is Arch's. Harmless today (both 5.3), but it means `chsh` to the store path is still an open option, with the same `/etc/shells` friction zsh would have had.
4. ~~The remaining ~58 non-git aliases have not been trimmed yet.~~ **Done 2026-09-20: 58 → 12.** See "The alias trim" below.
