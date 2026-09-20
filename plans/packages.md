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

> **Revised 2026-09-20.** The original design was binaries-only, on the grounds that Omarchy configures these tools already. Under the parity rule in `foundation.md` that reads differently: *"Omarchy already configures it"* is the same sentence as *"the Mac will not have it configured"*. Tools with real configuration now get a shared module that owns it, so the two machines match and the config is edited in one place. `home.packages` keeps only what needs no configuration at all. The section below is the original reasoning, kept because the conflict analysis in it still holds; "What changed" follows it.

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

## What changed, and how parity actually works

A tool's configuration lives in `modules/<tool>.nix`, both hosts import it, and editing it once changes both machines. That is the whole mechanism — no templating, no copying, no per-host duplication. `modules/fzf.nix` was already this shape; `starship.nix`, `bat.nix` and `aliases.nix` follow it.

| Module | Carries |
|---|---|
| `starship.nix` | Omarchy's `starship.toml`, verbatim |
| `bat.nix` | `theme = "ansi"`, plus bat-as-`MANPAGER` |
| `aliases.nix` | Omarchy's eza aliases, `..`/`...`/`....`, zoxide and the `zd` function |
| `fzf.nix` | the `Ctrl-R` integration |

### Theming turned out not to be the obstacle

The fear was that Omarchy's configs are themed and its theme system is Linux-only. They are not, in the way that mattered. Omarchy's `starship.toml` uses **named** ANSI colours — `bold cyan`, `italic cyan` — and its bat theme is literally `ansi`. Both resolve against the terminal's sixteen-colour palette rather than hardcoding hex values.

So Omarchy already defers colour to the terminal, and the same config produces the same appearance on any terminal themed the same way. Cross-machine theming collapses into the terminals section instead of being a per-tool problem. The exceptions are `btop`, whose `color_theme = "current"` resolves through a symlink into `~/.local/state/omarchy/`, and the terminal configs themselves.

### What is portable, and what is not

Of Omarchy's shell layer, the portable part is most of it: the eza aliases, the navigation aliases, `zd`, and the tool configuration above. Deliberately not shared:

- **`open()`** — Omarchy wraps `xdg-open`; macOS has a native `open` that must not be shadowed.
- **`a` (omarchy-agent), `h` (herdr), `ic`/`ix`/`icx` (its `tdl` tmux helpers)** — wrap tools that do not exist on macOS.

Those stay in Omarchy's own layer, reached through `hosts/beelink/omarchy.nix`.

### `zd` is the one that cannot be a package

Per zsh.md's rule, a helper that mutates the calling shell stays a shell function; everything else becomes a `writeShellScriptBin` derivation. `zd` calls `builtin cd`, so it is the function case, and it lives in `programs.bash.initExtra` rather than becoming a program.

### btop: two settings, not a config file

Omarchy ships a 10KB `btop.conf`. Diffed against the config btop generates for itself, it differs in exactly two places:

```
color_theme = "current"     (btop default: "Default")
vim_keys    = true          (btop default: false)
```

Everything else is stock. So `modules/btop.nix` declares those two and lets btop supply the rest, rather than carrying 280 lines of defaults that would silently drift from whatever btop ships next.

**btop is the one tool in the sweep whose theme is hex, not named ANSI colours** — `theme[main_bg]="#282828"` — so unlike starship and bat it does not follow the terminal palette for free. `color_theme = "current"` is therefore an indirection each machine satisfies its own way: on Omarchy, `~/.config/btop/themes/current.theme` is a symlink Omarchy manages into `~/.local/state/omarchy/current/theme/btop.theme`, so btop follows the active Omarchy theme. On macOS nothing provides it yet, and the Mac host will need to — either `programs.btop.themes.current` or a theme file in this repo.

That works because `programs.btop` only writes themes it is explicitly given: declaring `settings` alone leaves `~/.config/btop/themes/` untouched. Verified after switching — the Omarchy symlink is still in place and still resolves. Declaring `themes.current` here would replace it with a static file and break Omarchy's theme switching, which is a feature in use.

One aside that looks like a bug and is not: home-manager renders btop booleans as `True`/`False` rather than lowercase. btop accepts it — fed `vim_keys = True`, it parses and writes back `vim_keys = true`.

### lazygit: nothing to share

Omarchy's `lazygit/config.yml` is a **0-byte file** — both at `/etc/skel` and in `/usr/share/omarchy/config`. There is no configuration to carry across, so there is no `modules/lazygit.nix`. lazygit stays a binary in `home.packages` and both machines get its own defaults, which is already parity.

This is the "ask whether it is needed" test answering itself: the module that would have been written to achieve parity turns out to be unnecessary *for* parity. Worth recording so the empty file is not mistaken later for an oversight.

### A copying hazard worth recording

Omarchy's `starship.toml` contains Nerd Font glyphs in the private use area — `U+EBAB`, `U+F00C`, `U+EA71` for the conflicted, up-to-date and modified git states. They render as nothing in a terminal without that font, so transcribing the file by eye silently dropped all three and produced a prompt missing its git icons. The fix was to generate the Nix from the file's actual bytes and annotate each glyph with its codepoint. Any future config copied out of Omarchy should be diffed *semantically* — `tomllib`, not the eye — before being trusted.

## Open questions

1. **`mise` overlaps with Nix by definition.** Both are version managers; Omarchy installs and activates mise, and the reference setup used it for language runtimes. Left to Omarchy for now, on the grounds that nothing is broken — but "Nix pins everything except the language toolchains, which mise pins separately" is a split worth making deliberately rather than by default.
2. ~~`starship`, `zoxide` and `fzf` are installed here but initialised by Omarchy.~~ **fzf resolved 2026-09-13**, in [`modules/fzf.nix`](../modules/fzf.nix); `starship` and `zoxide` still open.

   The fzf case was the fragile one. Omarchy's rc sources `/usr/share/fzf/key-bindings.bash`, which `pacman -Qo` reports as owned by `fzf 0.74.3-1` — so once Nix supplied the binary, `Ctrl-R` depended on a pacman package that was no longer providing the tool. Removing it as an apparent duplicate would have broken `Ctrl-R` silently: the `command -v fzf` guard still passes, because Nix's fzf answers it, and the `source` then finds nothing.

   `programs.fzf` with `enableBashIntegration` emits `eval "$(fzf --bash)"` from the store. Verified three ways: the integration alone binds `Ctrl-R` to `__fzf_history__` in a `--norc` shell with no Omarchy and no `/usr/share`; `fzf --bash` contains **zero** references to `/usr/share`; and it lands at `mkOrder 200` in `programs.bash.initExtra`, after `modules/bash.nix` sources Omarchy's rc from `bashrcExtra`, so these are the bindings that end up installed.

   Omarchy's own fzf lines still run first while pacman's fzf is present. There is no supported way to suppress them — its shell layer has no opt-out variable, and its hooks fire on system events, not shell init — so the cost is one redundant `source` per interactive shell. Accepted knowingly; the alternative is to stop sourcing Omarchy's `init` altogether, which would mean taking over mise, starship, zoxide and `try` in the same change, and forcing a starship-config decision that has not been made.

   The same change filled a real gap: `FZF_DEFAULT_COMMAND` and `FZF_DEFAULT_OPTS` were unset, since Omarchy sets neither. Both are carried over from the reference setup's `conf.d/30-fzf.zsh` — the only lines in that file not concerned with locating Homebrew's copy of fzf.

3. **`tmux` and `neovim` are deliberately absent from this list.** Both have substantial configuration in the reference setup and both are seeded by Omarchy into `~/.config`, so they get their own sections rather than being quietly pinned here.
4. **`imagemagick`, `gum`, `unzip`** are left to Omarchy: `gum` is used by Omarchy's own scripts and should stay coherent with them, and the other two are closer to system libraries than typed commands.
5. **The macOS list is roughly fifty packages** because Homebrew had to supply what Arch gets from pacman. Most of it — `curl`, `git`, `lua`, `libpq`, `mysql-client`, `yarn`, `mas`, `switchaudio-osx`, `reattach-to-user-namespace` — needs the same keep/drop/rebuild pass before the macOS host exists. GUI casks are a separate question again, and tied to foundation.md open question 5.
