# Plan: macOS — the parity test

Revision 1. The experiment this repository rests on. Depends on every section before it.

## Problem

`foundation.md` justifies Nix partly on one claim: that one configuration can serve Omarchy and macOS, edited once and applied to both. Until a macOS host exists, that claim is **untested** — and every parity decision made while building the Linux side has been speculative.

The claim is also falsifiable, which makes it worth testing rather than assuming:

```
small host file   the shared modules genuinely abstract both platforms
large host file   most config is platform-specific after all, and two simpler
                  per-platform setups would beat one clever shared one
```

## Rejected approaches

- **A fresh macOS install.** Destructive, slow, and it tests the wrong thing. The Mac runs chezmoi today and `foundation.md` requires both systems working simultaneously — wiping it destroys the control group. It would answer "does bootstrap work on bare macOS" when the open question is "do the modules port", which is cheaper to answer and answerable without reinstalling anything.
- **nix-darwin from day one.** It writes `/etc/bashrc`, `/etc/zshrc` and friends and manages system defaults. None of that is needed to test whether the shared modules port, and standalone home-manager is trivially reversible. This resolves `foundation.md` open question 3: **standalone first**, nix-darwin when macOS system defaults are actually wanted.
- **Activating straight onto the working account.** The Mac's chezmoi setup is the thing being compared against. A second macOS user account gives a genuinely clean home directory at zero risk to it.

## Chosen design

**Four phases, escalating risk, stoppable at any point.**

### Phase 0 — evaluate from Linux, no Mac involved (done)

Nix **evaluation is cross-platform**; only *building* needs the target system. So `hosts/macbook-pro/` can be written and evaluated from the Beelink, catching module errors, option type errors and assertion failures before the Mac is touched at all.

This also answers the experimental question on its own.

### Phases 1–3 — on the Mac

1. **Read-only.** Install Nix with the same `NixOS/nix-installer` (darwin-capable), then `nix build` **only** — never `switch`. The generation is produced without linking anything, so `home-files/` can be inspected to see exactly what *would* be placed, and diffed against what chezmoi currently manages. The collision list is known before anything moves.
2. **Isolated.** A second macOS user account, with its own home directory. `home-manager switch` there. The real account stays on chezmoi, untouched. This is the side-by-side comparison with the Beelink, at zero exposure.
3. **Migrate** the real account once satisfied, with `-b bak` as on Linux, releasing chezmoi from whatever home-manager takes over.

## Phase 0 result: the experiment passed

Predicted beforehand: roughly six overrides. Actual: **seven**, in 43 lines excluding comments.

| Override | Why it exists |
|---|---|
| alacritty snapshots | no `/usr/share/omarchy` to import from |
| font size 9 → 14 | retina display |
| decorations `None` → `buttonless` | macOS draws its own titlebar; Hyprland does not |
| starship snapshot | nothing to symlink to |
| tmux snapshot, `unbind ?` | that binding shells out to `omarchy-menu-tmux-keybindings` |
| btop `color_theme` | no Omarchy theme state for `current` to resolve |
| `coreutils` | GNU behaviour over BSD — undoes a difference Linux does not have |

Against that: **12 shared modules, 705 lines, imported verbatim.** The only module the Mac does not take is `hosts/beelink/omarchy.nix`, which is Omarchy glue by definition.

### The shared modules produce the same output on both platforms

Evaluated for both hosts and compared:

```
home.shellAliases        IDENTICAL
programs.git.settings    differs only in store hashes (gh, git-template —
                         same package, different architecture)
home.sessionVariables    differs only in /home vs /Users, plus
                         LOCALE_ARCHIVE_2_27 (Linux glibc) and
                         TERMINFO_DIRS (darwin) which home-manager adds itself
```

**No semantic divergence.** Every difference is an architecture artifact or a correct platform path.

Also confirmed: all 25 declared packages build for `aarch64-darwin`, and `option_as_alt = "Both"` reaches the Mac from the shared module — without it, all 26 of Omarchy's prefix-less Alt bindings in tmux would silently do nothing there, since macOS Option composes characters by default.

## Phase 1 result: it builds, and the collisions are clean

Run 2026-10-01 over SSH. The Mac turned out to need no installer — Nix 2.35.2 was already there, from the same `NixOS/nix-installer` (`/nix/receipt.json` present), with flakes enabled and `/nix` on its own APFS volume at `/dev/disk3s7`. That is the macOS counterpart of the Btrfs subvolume, and the installer had done it unprompted.

**Every derivation built on `aarch64-darwin`.** This was the first time any of them had been built rather than evaluated, and nothing failed.

Sixteen files would be placed, against the Beelink's sixteen — a coincidence of count, not of content. The Mac drops the Linux-only three (`environment.d`, `systemd/user/tray.target`, `hyprland-xdg-terminals.list`) and gains the two alacritty snapshots plus `Library/Fonts/.home-manager-fonts-version`, which home-manager adds on darwin by itself.

Six collisions, **all six owned by chezmoi**:

```
.config/alacritty/alacritty.toml    .config/git/config
.config/btop/btop.conf              .config/starship.toml
.config/gh/config.yml               .config/tmux/tmux.conf
```

No unmanaged-file surprises, which is the outcome that makes Phase 3 tractable: every collision is a file whose other owner can be told to let go.

### The finding Phase 1 actually turned up

`.bashrc`, `.bash_profile` and `.profile` are **not** collisions, because they do not exist on the Mac. The login shell there is `/opt/homebrew/bin/zsh`, and chezmoi manages `.config/zsh/` — the full 26-file reference setup.

So a switch on the Mac would place a complete bash configuration that **nothing would read**. Every alias, the history settings, the ported Omarchy functions: all inert until the shell changes.

That is not a defect in the modules; it is [`shell.md`](shell.md)'s deferred decision arriving on the machine where it actually bites. Three ways out, none free:

1. **`chsh` the Mac to bash.** Consistent with Omarchy, and the config works immediately. Costs the Homebrew zsh setup that works today.
2. **Revisit zsh.** `shell.md` chose bash on the strength of Omarchy's 22 shell functions, which do not exist on macOS — so the argument that settled it is weakest precisely here. `zsh.md` is still accurate and the content is already shell-neutral.
3. **Different shells per machine.** Against the parity rule, and it would double the surface.

Not decided here. It needs deciding before Phase 3, because until then the Mac gets files it never reads.

## Phase 2 result: it activates, and Apple's bash is unusable

Switched on a throwaway `nixtest` account 2026-10-01. Activation succeeded, including the darwin-only steps home-manager runs by itself: `checkAppManagementPermission`, `copyApps` (populating `~/Applications/Home Manager Apps`), `setupLaunchAgents`, and `batCache`.

**All 24 declared tools resolve to the nix profile, none to the system, none missing** — and the versions are identical to the Beelink's: `bat 0.26.1`, `fd 10.5.0`, `ripgrep 15.2.0`, `fzf 0.74.4`, `jq 1.8.2`, `starship 1.26.0`, `zoxide 0.10.0`, `git 2.55.0`. That is the parity claim made concrete rather than argued.

### Apple's bash 3.2 breaks the configuration, and not gently

macOS ships bash 3.2.57, frozen at the last GPLv2 release in 2007. Starting an interactive shell against our generated `.bashrc`:

```
bash: shopt: globstar: invalid shell option name
bash: shopt: checkjobs: invalid shell option name
bash: .bashrc: line 41: conditional binary operator expected
bash: .bashrc: line 41: syntax error near `BASH_COMPLETION_VERSINFO'
```

The first two are noise — bash 4.0 options that 3.2 rejects and moves past. The third is a **syntax error**, and it is fatal to everything after it. Line 41 is home-manager's own bash-completion guard, `[[ ! -v BASH_COMPLETION_VERSINFO ]]`, and `-v` is a bash 4.2 test operator.

Everything in `initExtra` is therefore lost:

```
zd         MISSING      Ctrl-R fzf   not bound
tdl / tds  MISSING      try          binary only, integration never ran
```

The aliases survive only because `home.shellAliases` is emitted *before* that line. So the failure is partial and silent — a shell that looks configured, with half its behaviour missing.

Under the nix-provided bash 5.3.15 the identical `.bashrc` loads clean: `zd`, `tdl`, `tds` and `try` are all functions, `Ctrl-R` is bound, no errors. The Beelink runs bash 5.3 as well, so this is also what makes the two machines genuinely the same shell.

**Conclusion: a macOS host must not use `/bin/bash`.** The login shell has to be the nix one, which needs its path in `/etc/shells` before `chsh` will take it — the same friction [`bootstrap.md`](bootstrap.md) open question 6 records for Omarchy, now confirmed as a hard requirement rather than a preference. `/bin/bash` remains fine for *creating* the account, since `home-manager switch` is a nix command and does not care what the login shell is.

### What Phase 0 does not prove

It evaluates; it has not been built or activated. Specifically untested: that every derivation builds on darwin, that activation succeeds, that the fonts render, that the palette actually matches side by side, and that the bootstrap path works end to end on a machine that has never had Nix. Those are Phases 1–3.

## Open questions

1. **The palette snapshot is frozen by design.** `modules/alacritty/omarchy-theme.toml` is the Gruvbox theme active when it was taken. The Mac has no `omarchy-theme-set`, so a theme change on Omarchy will not follow. Either that is accepted, or theme switching needs a macOS answer — shipping several and selecting one, as the reference setup did with four Catppuccin variants.
2. **btop falls back to its default theme on macOS.** Unlike starship and bat, btop's theme is hex rather than named ANSI colours, so it does not follow the terminal palette for free. Matching it would mean snapshotting `btop.theme` too.
3. **Omarchy's shell layer has no macOS equivalent**, and that is the largest felt difference: 28 aliases and 22 functions, of which only the portable subset was shared. `rsw`/`lsw`/`dsw` specifically use `inotifywait` and `setsid` and would need an `fswatch` rewrite — not currently used, so not done.
4. ~~The hostname and username are assumed.~~ **Confirmed 2026-10-01:** `faleman@macbook-pro`, `/Users/faleman`.
5. **A second Mac is coming.** The reference repo carries `push-to-mac-studio` and `pull-from-mac-studio`, and the MacBook Pro is being tested first precisely so the desktop is not disturbed. That matters structurally: of the seven overrides in `hosts/macbook-pro/`, **six are macOS-wide** — the snapshots, `buttonless`, `coreutils`, the btop theme — and only `font.size` is specific to this machine. When the second Mac lands, those six want factoring into a `modules/darwin.nix` that both Macs import, leaving each host with little more than a font size. Not done now: one Mac is not evidence of a shared layer, and guessing at the split before the second machine exists is how premature abstraction gets in.
