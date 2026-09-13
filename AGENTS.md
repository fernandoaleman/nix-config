# Working on this repository

Nix + home-manager configuration for Omarchy (Arch) and macOS. **Not NixOS** — Omarchy
remains the operating system on Linux, macOS remains macOS, and home-manager is the one
layer both machines share.

**Current state: the flake exists and one generation has been activated; no modules are
written yet.** `flake.nix` pins nixpkgs-unstable and home-manager master, and
`hosts/beelink/` is a minimal host that switches cleanly — username, home directory,
`stateVersion`, `xdg.enable`, and `programs.home-manager.enable`, nothing more. `modules/`
does not exist yet; it is created when the first shared module is written.

The design lives in [`plans/`](plans/) and [`plans/foundation.md`](plans/foundation.md) is
the entry point — read it before proposing or writing anything.

Note that Nix only sees files git knows about: a new `.nix` file must be `git add`ed
before `nix build` or `make switch` will find it, or evaluation fails claiming the file
does not exist.

## The binding constraint: rebuild, do not port

This repository replaces a chezmoi setup at `fernandoaleman/dotfiles` (private). That
repository is a **requirements document, not source material.**

For every item the question is: *"how would someone who had only ever used Nix write this
from scratch to produce the same behavior?"* — never *"how do I bring the existing shell
code across?"*

Concretely forbidden:

- `xdg.configFile."…".source = ./old-file` wrapping a file lifted from the old repo
- Reproducing the old `conf.d/NN-name` numbering, or numeric filename prefixes anywhere
- Reaching for `initContent` / `extraConfig` where a home-manager module option exists
- Preserving platform conditionals that only existed because Homebrew and pacman put
  files in different places — under Nix both machines resolve the same store paths, so
  those requirements disappear rather than getting translated

The reason is not aesthetics. The old repo still carries a scar from the migration before
this one: `conf.d/00-homebrew.zsh.tmpl` opens with `Converted from yadm alternate:
homebrew.zsh##o.Darwin,a.arm64`, two managers later. The finished repository must read as
though it were natively Nix-authored.

## Ask whether it is needed before building it

Applied to every item before any module is written. Roughly half of the ~200 shell aliases
are not expected to survive; `create-ansible-docker-image` has already been retired on
these grounds; the bootstrap `create-dirs` script dissolved entirely once home-manager's
own behavior was accounted for.

When reviewing a section, enumerate what the old setup did, then decide keep / drop /
rebuild for each item **before** writing Nix.

## Both machines, as close to identical as possible

Omarchy and the Mac should differ only where the platform forces it. Before any
decision, weigh it on both:

- **Can it be the same on both?** Then make it the same, even if one machine already
  has something like it.
- **Can it not?** Then say so explicitly, and choose the option that leaves the two
  closest, rather than the one that is most convenient on whichever machine is in front
  of you.

There is a specific trap here. *"Omarchy already does this, so home-manager does not need
to"* is the same sentence as *"the Mac will not have this"* — Omarchy's shell layer, its
aliases, its functions and its tool initialisation do not exist on macOS. Leaning on them
is a decision to diverge, and it should be made deliberately or not at all.

The layout encodes this: `modules/` is for what runs on both, `hosts/<name>/` is for what
cannot. Anything Omarchy-specific belongs under `hosts/beelink/`, not in a shared module.

## This repository is public

`fernandoaleman/nix-config` is public so a bare machine can be brought up with `git clone`
before any authentication exists. Nothing private is ever committed — not encrypted, not
obfuscated.

Never commit: SSH keys, API tokens, AWS config or account IDs, ARNs, IAM role names,
Atlassian/Jira URLs or custom-field IDs, work email addresses, employer name, internal
hostnames, or VPN profiles. Work-specific *values* live outside the repo entirely; see
[`plans/secrets.md`](plans/secrets.md). Code that needs them reads them at runtime — for
example, enumerating AWS profiles via `aws configure list-profiles` rather than hardcoding
a list.

If a task seems to require committing any of the above, stop and raise it rather than
finding a way around it.

## The Omarchy boundary

Omarchy owns these. Nix must not declare them:

- `~/.config/hypr/*.lua` (all six) and `hypr/.luarc.json`
- `~/.config/omarchy/shell.json`, `omarchy/extensions/omarchy-menu.jsonc`
- `~/.config/omarchy/plugins/**` and `omarchy/themes/**` — nested git clones managed by
  `omarchy-plugin-*` and `omarchy-theme-update`
- `~/.local/state/omarchy/**` — generated theme state

Omarchy's automatic config refresh is hash-guarded and leaves customized files alone, but
three paths bypass that guard: `always_copy_config_files`, 17 of 116 migrations that write
in place, and `omarchy-refresh-config`. home-manager writes read-only store symlinks, so
anything it owns inside that set will be silently un-managed or will hard-fail a
migration. `plans/foundation.md` has the mechanics.

## Conventions

- **Named files, never numeric prefixes** — following Omarchy's own `plans/` and `bin/`.
  Where ordered scripts are eventually needed, use named scripts sourced in order by one
  entry point, in the shape of Omarchy's `install/config/all.sh`.
- **Conventional commits**, enforced by `committed` via `prek` on `commit-msg`.
  Run `make setup` once per clone — git hooks do not travel with a clone.
- **`make lint`** runs every hook over every file.
- **Directory creation is configuration, not a build task** — `home.activation` or
  `home.file`, never a Makefile target. This governs `$HOME`. System-level provisioning
  that must happen *before Nix exists* — creating the `/nix` Btrfs subvolume — cannot be
  configuration by definition, and belongs to `make bootstrap`; see
  [`plans/bootstrap.md`](plans/bootstrap.md).
- Plans follow Omarchy's planning-document convention: revision-numbered, stating the
  problem, the approaches rejected and why, the chosen design, and open questions. Update
  the relevant plan when a decision is made, in the same change that acts on it.

## Verify against source, not memory

home-manager option names and Omarchy behavior are checked against the actual module
source or the Omarchy tree before being relied on or written into a plan. Several
assumptions have already been wrong in ways that looked plausible. State plainly when
something is an inference rather than an observation.

`plans/foundation.md` carries four verification items that must be confirmed on a live
Omarchy machine **before any module is written** — one of them, putting `/nix` on its own
Btrfs subvolume, has no second chance once Nix is installed.
