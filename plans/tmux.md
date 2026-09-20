# Plan: tmux — Omarchy's config, carried whole

Revision 1. Depends on [`terminals.md`](terminals.md), whose palette decision this one builds on.

## Problem

Two complete tmux configurations exist and they disagree about almost everything except the prefix. Omarchy ships one at `/usr/share/omarchy/config/tmux/tmux.conf`, seeded into `~/.config/tmux/`; the reference setup has its own, with TPM plugins and a `sesh` binding.

| | Omarchy | Reference setup |
|---|---|---|
| Prefix | `C-Space` (with `C-b` as prefix2) | `C-Space` |
| Split | `M-Enter` / `M-S-Enter`, prefix-less | `prefix \|` / `prefix -` |
| Pane focus | `C-M-arrows`, prefix-less | vim-tmux-navigator (commented out) |
| Windows | `M-1`…`M-9`, `M-arrows`, prefix-less | defaults |
| Theme | named colours | `catppuccin-tmux` (hex) |
| Plugins | none | tpm, resurrect, continuum, catppuccin |
| History | 50000 | 1000000 |

## Rejected approaches

- **The reference setup's config.** Rejected on two technical grounds rather than taste. Its theme is `catppuccin-tmux`, which is hex, and would undo the palette parity `terminals.md` just established — the whole point of standardising on alacritty was that named colours follow the terminal on both machines. And it has no `extended-keys` setting, so the CSI-u keybindings in `modules/alacritty.nix` would arrive as ordinary Enter.
- **TPM.** `programs.tmux.plugins` installs plugins from nixpkgs directly, so the plugin manager and the `run_once_after_20-setup-tmux-plugins.sh` bootstrap both disappear rather than getting ported.
- **`set-option -g default-shell /usr/bin/zsh`.** Obsolete — see [`shell.md`](shell.md).
- **home-manager's `prefix`, `keyMode` and `clock24` options.** See below; this is the substantive finding.

## Chosen design

**Omarchy's `tmux.conf`, carried whole**, with `history-limit` raised to the reference setup's 1000000 and the one Omarchy-only binding moved to the host.

It wins on two properties that only became visible after the terminals work:

- **Its theme is written entirely in named colours** — `blue`, `black`, `brightblack`, `default` — so it resolves against the terminal palette and matches on both machines for free. Same property that made starship and bat portable.
- **It sets `extended-keys on` with `extended-keys-format csi-u`**, which is the receiving end of the four CSI-u bindings in `modules/alacritty.nix`. They are a matched pair: Shift+Enter reaching tmux as distinct from Enter only works because both halves agree.

### home-manager's convenience options each did more than they appeared to

The obvious shape was to map Omarchy's settings onto `programs.tmux`'s native options. Three of them silently changed behaviour, each caught by starting a tmux server on both configs and diffing `list-keys` and `show-options`:

| Option | What it also did |
|---|---|
| `prefix` | Emits `unbind C-b` before rebinding, destroying tmux's default `C-b send-prefix`. Omarchy keeps `C-b` as `prefix2`, so that default is load-bearing |
| `keyMode` | Sets `status-keys` as well as `mode-keys`, moving the command prompt from emacs editing to vi. Omarchy sets only `mode-keys` |
| `clock24` | Defaults to `false` and is emitted **unconditionally even when unset**, writing `clock-mode-style 12` where Omarchy inherits tmux's 24-hour default |

The first two are avoided by letting Omarchy's own lines do the work. The third cannot be — it is written whether or not the option is set — so `clock24 = true` appears in the module not as a preference but to cancel a default that would otherwise diverge.

The generated config now matches Omarchy's binding for binding (309 of them) and option for option, with `history-limit` the only difference.

**The general lesson:** a home-manager option that looks like a one-line setting may bundle several. When adopting a config wholesale, prefer its own lines and verify by diffing the program's *runtime* state, not the generated file.

### The dev-layout helpers come too

`tdl`, `tds`, `tdlm` and `tsl` live in Omarchy's `default/bash/fns/tmux` and are undocumented — absent from its menu and its agent docs. They are layout builders, not session managers:

- `tdl <ai> [<ai2>]` — renames the window after `$PWD`, then editor left, AI right at 30%, terminal below at 15%. The `ic`/`ix`/`icx` aliases are wrappers.
- `tds` — a 2×2 grid: editor, `hunk diff --watch`, terminal, opencode.
- `tdlm <ai>` — one `tdl` window per subdirectory, session renamed after the parent.
- `tsl <n> <cmd>` — n tiled panes all running the same command.

They depend on nothing Omarchy-specific — tmux, `$EDITOR`, and whatever command is passed in — so they are shared rather than left in the host, and work on macOS where Omarchy's own copies will not exist.

They stay **shell functions** rather than becoming `writeShellScriptBin` derivations, which the rule in zsh.md would otherwise suggest. Omarchy defines these same names as functions, and a function always beats a script on `PATH`; declaring them in `initExtra`, which lands after Omarchy's rc, is what makes this copy the one that wins on both machines.

One upstream bug fixed on the way: `tdl` ends with `tmux select-pane -t "$opencode_pane"`, but that variable only exists in `tds`, so the final focus targets an empty string and does nothing. Ours targets `$editor_pane`.

### Session management without `sesh`

The reference setup bound `sesh` to `prefix k`. It is not carried over by default, because tmux's own `prefix s` — `choose-tree -Zs`, which Omarchy leaves untouched — covers most of it. From tmux's man page, tree mode offers `C-s` search by name, `f` filter, `Enter` switch, `x` kill, `X` kill tagged, `t`/`T`/`C-t` tagging, `v` preview, `O`/`r` sort.

What it does **not** do is create a session for a directory that is not already open. `prefix C` creates one in the current pane's path, and that is the limit. `sesh`'s value is its zoxide integration: fuzzy-find any directory ever visited and start a session there in one keystroke. It is in nixpkgs (2.30.1) and works on both machines, so it remains a one-line addition if that gap is felt.

## Open questions

1. **`sesh`** — see above. Worth living on `prefix s` for a while first; the gap is specific and easy to recognise.
2. **`tmux-resurrect` and `tmux-continuum`** from the reference setup are not carried over. `programs.tmux.plugins` would install them from nixpkgs with no TPM. Whether session persistence across reboots is still wanted has not been decided.
3. **`gitmux`** (0.11.5 in nixpkgs) rendered git status in the old status bar. Omarchy's status bar does not use it, and adopting Omarchy's design means it has nowhere to go unless the status-right format changes.
4. **`escape-time` is set twice** in Omarchy's config — `set -g escape-time 0` and later `set -sg escape-time 10`. Carried across verbatim rather than "fixed", since the last write wins and changing it would alter behaviour this repo did not intend to touch.
