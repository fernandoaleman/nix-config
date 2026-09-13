# nix-config

Nix + home-manager configuration for [Omarchy](https://omarchy.org) (Arch) and macOS.

Not NixOS — Omarchy remains the operating system on Linux, macOS remains macOS, and
home-manager is the single layer both machines share.

## Status

Planning. Nothing is built yet.

The design lives in [`plans/`](plans/), following the convention Omarchy uses for its
own planning documents — each revision-numbered, stating the problem, the approaches
rejected and why, the chosen design, and the questions still open.

- [`plans/foundation.md`](plans/foundation.md) — the overall design, repository layout,
  the Omarchy boundary, and what must be verified on a live machine first
- [`plans/zsh.md`](plans/zsh.md) — the shell, rebuilt natively
- [`plans/secrets.md`](plans/secrets.md) — keeping private material out of a public repo
  (decision deliberately deferred)

## A note on method

This repository replaces a chezmoi setup. Nothing is ported from it: each piece is
rebuilt from what it needs to *do*, written the way it would have been written had Nix
been the only tool ever used. The old repository is a requirements document, not source
material.
