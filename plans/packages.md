# Plan: packages — what Nix owns, and what it deliberately does not

Revision 1. Depends on [`foundation.md`](foundation.md) and [`shell.md`](shell.md).

## Problem

This is the section the whole repository was justified by. From foundation.md: *"`.chezmoidata/packages.toml` says 'install starship.' It does not say which starship. Two machines built from the same repo are similar, never identical, and a `pacman -Syu` or `brew upgrade` can change either one underneath."*

But the situation on Omarchy is not a blank slate. Three package managers already have opinions:

- **Omarchy installs 206 packages** across `omarchy-base.packages` and `omarchy-other.packages`, including most of the CLI set: `bat`, `btop`, `eza`, `fd`, `fzf`, `gum`, `imagemagick`, `jq`, `lazygit`, `ripgrep`, `starship`, `tldr`, `tmux`, `unzip`, `zoxide`.
- **The reference setup added its own** — on Arch: `age`, `gnupg`, `ncdu`, `nmap`, `rclone`, `rsync`, `shellcheck`, `wget`, plus several now redundant because Quattro ships them. On macOS the Homebrew list is roughly fifty, because Homebrew had to supply everything.
- **mise** manages language runtimes, and Omarchy activates it from its own shell rc.

So the question is not "which packages" but **"which packages should Nix own, given something already installs them"**.

## Rejected approaches

- **Let Nix install everything, including Omarchy's 206.** Would mean Nix supplying Hyprland, the display stack, fonts and drivers — which is NixOS by the back door, and foundation.md rejected NixOS because Omarchy is the thing being kept.
- **Let Nix install nothing that pacman already provides.** The tidy-looking answer, and it gives up the entire stated benefit. `bat` and `ripgrep` are exactly the tools that should be identical on both machines and pinned by `flake.lock`; leaving them to `pacman -Syu` is the problem this repository exists to solve.
- **Use `programs.*` modules for the CLI tools in this pass.** `programs.eza` writes `ls` aliases, `programs.bat` sets a theme, `programs.fzf`/`programs.zoxide`/`programs.starship` each add a shell init. Omarchy's rc **already** aliases `ls` to eza, already exports `BAT_THEME=ansi`, and already runs `starship init bash`, `mise activate bash`, `zoxide init bash` and sources fzf's key bindings. Every one of those modules would fight the layer `modules/bash.nix` deliberately preserves, and several would produce a visible double-init. Deferred to per-tool modules, where each conflict can be resolved on purpose rather than by accident.

## Chosen design

**`home.packages` only.** This pass installs binaries and pins them. It configures nothing and touches no shell integration.

That is not a compromise — it is the whole benefit with none of the conflict surface. `flake.lock` pins the versions, both machines resolve the same store paths, and `~/.nix-profile/bin` precedes `/usr/bin` on the PATH (verified: positions 1 and 5 of a login shell), so the Nix build wins wherever both exist. Omarchy's `eval "$(starship init bash)"` resolves `starship` through that same PATH, which means Omarchy's shell layer transparently initialises *Nix's* binary. Nothing needs suppressing.

### The rule

**Nix owns a package when you type its name. Omarchy owns the system and desktop layer.**

`bat`, `fd` and `ripgrep` are things a person invokes and would notice changing. Hyprland, mesa, fonts, pipewire and the other ~190 are things the operating system provides and Omarchy is responsible for keeping coherent with its own compositor and theming. The line is not "who installed it first", it is "whose job is it to keep this working".

Applying it to the reference setup, with the "ask whether it is needed" test from foundation.md:

| Package | Disposition |
|---|---|
| `bat`, `eza`, `fd`, `ripgrep`, `fzf`, `jq` | **Nix.** Typed constantly, wanted identical on both machines |
| `btop`, `ncdu` | **Nix.** Typed |
| `lazygit` | **Nix.** Typed |
| `wget`, `rsync`, `rclone`, `nmap` | **Nix.** From the reference setup's own Arch list |
| `age`, `gnupg` | **Nix.** Needed by `secrets.md` |
| `shellcheck` | **Nix.** Used on this repository's own scripts |
| `tldr` | **Nix.** Typed |
| `git`, `delta`, `gh` | Already Nix, via `modules/git.nix` |
| `chezmoi` | **Dropped.** It is what this repository replaces |
| `colordiff` | **Dropped.** Superseded by delta |
| `thefuck` | **Dropped.** Unmaintained upstream |
| `zsh`, `zsh-autosuggestions`, `zsh-completions`, `zsh-syntax-highlighting` | **Dropped.** See `shell.md` |
| `coreutils` | **macOS only** if at all — it exists to get GNU behaviour over BSD, a requirement that does not exist on Linux |
| Hyprland, fonts, drivers, ~190 others | **Omarchy.** Not Nix's business |

## Open questions

1. **`mise` overlaps with Nix by definition.** Both are version managers; Omarchy installs and activates mise, and the reference setup used it for language runtimes. Left to Omarchy for now, on the grounds that nothing is broken — but "Nix pins everything except the language toolchains, which mise pins separately" is a split worth making deliberately rather than by default.
2. **`starship`, `zoxide` and `fzf` are installed here but initialised by Omarchy.** That works — verified after switching: `starship --version` reports Nix's 1.26.0 and its config parses, `zd` is still a function, `ls` still resolves to eza, and `Ctrl-R` is still bound to `__fzf_history__`.

   **But fzf is split across two packages, and that is fragile.** Omarchy's rc sources `/usr/share/fzf/key-bindings.bash`, which `pacman -Qo` reports as owned by `fzf 0.74.3-1` — the *pacman* package. The binary those bindings invoke is now Nix's 0.74.4. That works, but it means `Ctrl-R` depends on a pacman package that is no longer the one supplying the binary. Removing pacman's `fzf` as an apparent duplicate would silently break `Ctrl-R`: the `command -v fzf` guard in Omarchy's init would still pass, because Nix's fzf answers it, and the `source` would then find nothing.

   So either pacman's `fzf` stays installed deliberately rather than incidentally, or `programs.fzf` takes over the integration and Omarchy's is suppressed. The second is cleaner and is the first per-tool decision worth making, because `Ctrl-R` is the binding actually relied on day to day.
3. **`tmux` and `neovim` are deliberately absent from this list.** Both have substantial configuration in the reference setup and both are seeded by Omarchy into `~/.config`, so they get their own sections rather than being quietly pinned here.
4. **`imagemagick`, `gum`, `unzip`** are left to Omarchy: `gum` is used by Omarchy's own scripts and should stay coherent with them, and the other two are closer to system libraries than typed commands.
5. **The macOS list is roughly fifty packages** because Homebrew had to supply what Arch gets from pacman. Most of it — `curl`, `git`, `lua`, `libpq`, `mysql-client`, `yarn`, `mas`, `switchaudio-osx`, `reattach-to-user-namespace` — needs the same keep/drop/rebuild pass before the macOS host exists. GUI casks are a separate question again, and tied to foundation.md open question 5.
