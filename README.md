# nix-config

Nix + home-manager configuration for [Omarchy](https://omarchy.org) (Arch) and macOS.

Not NixOS — Omarchy remains the operating system on Linux, macOS remains macOS, and
home-manager is the single layer both machines share.

## Status

Running on the Beelink. Nix is installed, and twelve modules cover the shell, git,
terminal, tmux, the CLI tools, mise and `try`. Omarchy still owns the system
layer, and its own configs are tracked *live* rather than copied — `omarchy update`
changes flow straight through.

Not done: secrets, and the macOS host.

```sh
make switch   # build and activate
make build    # build without activating
make check    # evaluate the flake
```

The design lives in [`plans/`](plans/), following the convention Omarchy uses for its
own planning documents — each revision-numbered, stating the problem, the approaches
rejected and why, the chosen design, and the questions still open.

- [`plans/foundation.md`](plans/foundation.md) — the overall design, repository layout,
  the Omarchy boundary, and the findings from verifying it on a live machine
- [`plans/bootstrap.md`](plans/bootstrap.md) — a fresh Omarchy install to a working
  machine, and the one step that must happen before Nix is installed
- [`plans/shell.md`](plans/shell.md) — bash, and why zsh is deferred
- [`plans/zsh.md`](plans/zsh.md) — the zsh design, deferred but still accurate
- [`plans/git.md`](plans/git.md), [`packages.md`](plans/packages.md),
  [`terminals.md`](plans/terminals.md), [`tmux.md`](plans/tmux.md) — one per section
- [`plans/secrets.md`](plans/secrets.md) — keeping private material out of a public repo
  (decision deliberately deferred)

## What this does and does not pin

The flake pins the *user* environment: packages, versions and configuration, identically
on both machines. It does not pin the system underneath it. Omarchy remains the operating
system on Linux and updates on its own schedule, so two machines built from the same
commit but with different Omarchy migration histories are similar, not identical.

That is an accepted trade, not an oversight — replacing the system layer would mean
replacing Omarchy, which is the thing being kept. It is written down here so the
guarantee is not over-trusted later.

## A note on method

This repository replaces a chezmoi setup. Nothing is ported from it: each piece is
rebuilt from what it needs to *do*, written the way it would have been written had Nix
been the only tool ever used. The old repository is a requirements document, not source
material.
