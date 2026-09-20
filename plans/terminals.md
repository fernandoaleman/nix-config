# Plan: terminals — alacritty on both machines

Revision 1. Depends on [`foundation.md`](foundation.md) and [`packages.md`](packages.md).

## Problem

The terminal is the load-bearing piece of cross-machine parity, for a reason that only became clear while doing `packages.md`: **it supplies the sixteen ANSI colours everything else resolves against.** Omarchy's starship config uses named colours (`bold cyan`), and its bat theme is literally `ansi`. Get the terminal palette the same and those match for free; get it wrong and no amount of shared config helps.

And here the two machines genuinely cannot run the same thing by default. **`foot` is Omarchy Quattro's default terminal** — the only one in `omarchy-base.packages`, the only one installed — and foot is Wayland-only. There is no macOS build and will not be one.

## Rejected approaches

- **foot on Omarchy, something else on macOS.** The honest minimum, and it diverges at exactly the layer where divergence costs the most. Two configs to keep in step, in different syntaxes, forever.
- **ghostty on both.** Omarchy ships a ghostty config and a theme template, and the reference setup had the macOS cask. Rejected because nixpkgs has no darwin build: the Mac would install it through Homebrew under nix-darwin, splitting the install mechanism for the one component that most needs to be identical.
- **kitty on both.** Genuinely viable — cross-platform in nixpkgs, Omarchy ships a config and a template. Alacritty won on the tiebreak below rather than on merit.

## Chosen design

**Alacritty, from Omarchy's own config, on both machines.**

nixpkgs has it for `aarch64-darwin` as well as Linux, so both machines install it the same way and `flake.lock` pins one version. It is also **Omarchy's canonical palette source**: `omarchy-theme-colors-from-alacritty` generates each theme's `colors.toml` *from* its `alacritty.toml`, so every Omarchy theme ships one and the other terminals' themes derive from it. Taking alacritty means taking the palette at its source rather than a derivation of it.

`modules/alacritty.nix` carries Omarchy's config — `TERM`, OSC 52 clipboard, JetBrainsMono Nerd Font, 14px padding, and the CSI-u keybindings that let TUIs and tmux distinguish Shift+Enter from Enter. Verified equal to Omarchy's by parsing both files, not by reading them.

home-manager's alacritty module rewrites the literal `\uXXXX` form into real escapes when it generates the TOML, so `"\\u001B[13;2u"` in Nix arrives correctly — which matters, because those four keybindings are the fiddliest part of the file.

### The one line that cannot be shared

`general.import` names where the colours come from, and that necessarily differs:

```
Omarchy   ~/.local/state/omarchy/current/theme/alacritty.toml
macOS     a palette kept in this repo (not yet written)
```

On Omarchy this keeps `omarchy-theme-set` working exactly as before — the terminal restyles live, and everything downstream follows. On macOS the plan is to extract the current Omarchy theme's palette into the repo and import that, so both machines show the same colours while Linux keeps dynamic switching. That is the reference setup's own approach, which shipped Catppuccin Mocha for the Mac and used Omarchy's live theme on Linux.

Worth noting the reference setup's Linux path was `~/.config/omarchy/current/theme/alacritty.toml`, which Omarchy 4 moved to `~/.local/state/`. It had been silently broken — the import simply found nothing.

### Making it the terminal Omarchy opens

`omarchy-launch-terminal` execs `xdg-terminal-exec`, which reads the first matching `<desktop>-xdg-terminals.list` it finds. `hosts/beelink/omarchy.nix` writes one naming `Alacritty.desktop` first and `foot.desktop` second, so foot remains a working fallback.

Two things cost time here and are worth recording:

- **The path is `~/.config/hyprland-xdg-terminals.list`, with no subdirectory.** `xdg-terminal-exec` looks for the bare filename under the *config* dirs and only uses an `xdg-terminal-exec/` subdirectory under the *data* dirs. Writing to `~/.config/xdg-terminal-exec/` silently does nothing. `XTE_DEBUG=1` prints the full search list and settles it.
- **It caches its decision** in `~/.cache/xdg-terminal-exec`, keyed on a hash of the config and data paths. A stale cache will keep resolving to the old terminal and make a correct change look broken.

Safe for home-manager to own: the path is not in `always_copy_config_files`, and no migration writes to it.

## Open questions

1. **Font size and window decorations will not stay shared.** `size = 9` and `decorations = "None"` are right for the Beelink under Hyprland, which draws no titlebar. A retina Mac wants a larger size — the reference setup used 20 against 12 — and `"buttonless"` rather than `"None"`. Both belong in the macOS host as overrides rather than being pre-emptively split now.
2. **Where the macOS palette comes from.** Extracting the *current* Omarchy theme freezes the Mac to whatever was active that day. Shipping several and choosing one is closer to what the reference setup did with its four Catppuccin variants. Neither is obviously right until the Mac exists.
3. **foot stays installed** as Omarchy's own package and second in the terminal list. Nothing removes it, and nothing should until alacritty has been the daily driver long enough to trust.
4. **`~/.local/share/applications/foot.desktop`** exists from Omarchy's provisioning and is unmanaged. It is only a fallback entry now, but it is a user-level file outside the Omarchy boundary list, so it is worth knowing about.
