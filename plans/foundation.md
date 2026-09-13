# Plan: Foundation — Nix + home-manager on Omarchy and macOS

Revision 1.

## Problem

Configuration currently lives in `fernandoaleman/dotfiles` (private), managed by chezmoi across macOS and Omarchy. Three things are wrong with it:

- **The edit loop has a gap.** chezmoi renders a source tree into targets, so changing a config means editing source and applying, or editing the target and re-adding. Checking `chezmoi status` became a routine step. The earlier thoughtbot `rcm` setup — where the file in the repo *is* the file — is the ergonomic that was lost.
- **Nothing pins versions.** `.chezmoidata/packages.toml` says "install starship." It does not say which starship. Two machines built from the same repo are similar, never identical, and a `pacman -Syu` or `brew upgrade` can change either one underneath.
- **Half the complexity exists only to span two operating systems.** 25 of 56 templates are pure OS conditionals, and files like `conf.d/30-plugins.zsh.tmpl` and `conf.d/30-fzf.zsh.tmpl` exist solely because Homebrew and pacman put files in different places.

There is also accumulated drift worth naming, since it motivated the audit: `.is_omarchy` silently returns different answers on upgraded versus fresh Omarchy 4 machines, and the alacritty and ghostty theme imports point at `~/.config/omarchy/current/`, a path Omarchy 4 moved to `~/.local/state/omarchy/current/`.

## Rejected approaches

- **NixOS.** Would replace Omarchy, which is the thing being kept. The one existing bridge, `henrysipp/omarchy-nix`, is explicitly unmaintained — its README says *"I've personally moved to using regular Arch Omarchy full-time... I'm not actively working on this repo"* — last pushed 2025-11-13, pinned to `nixos-25.05`, with zero references to quattro. Omarchy 4 rearchitected the desktop, the Hyprland config format, and the packaging, so that port is not a viable base.
- **A symlink manager (stow, rcm, tuckr, dotter).** Would fix the edit loop and nothing else. No version pinning, no package management, and `dotter`/`tuckr` reintroduce a templating engine — the same indirection being left behind, in a different language. `rcm` specifically is coasting: last commit 2024-08-16.
- **chezmoi's `mode = "symlink"`.** Tested in a sandbox: it symlinks plain files but renders templates as real files. With 56 templates and 19 encrypted files out of 149 managed, it fixes under half the friction, and not the confusing half.
- **Porting the existing configs into Nix.** Rejected as the *method*, not just as an outcome — see "Rebuild, do not port" below.
- **Two repositories, public base plus private work overlay.** Considered and dropped once the audit showed the employer-specific surface is configuration *values*, not code. A split would be permanent overhead to protect five items that can simply live out of the repo.

## Chosen design

**Nix as a package manager on a foreign distro, with home-manager as the shared layer.** Omarchy stays the operating system on Arch; macOS stays macOS. home-manager is the one layer both machines share, and Omarchy plays the role `nix-darwin` plays on the Mac.

```
macOS     nix + nix-darwin + home-manager
Omarchy   nix +             home-manager      (Omarchy owns the system layer)
```

Omarchy already accommodates this deliberately — it looks in the Nix profile in three places:

```
shell/services/hidden-entries.sh:102   scan_dir "$HOME/.nix-profile/share/applications"
bin/omarchy-launch-webapp:13           {~/.local,~/.nix-profile,/usr}/share/applications/$browser
bin/omarchy-launch-browser:10          {~/.local,~/.nix-profile,/usr}/share/applications/$default_browser
```

### Rebuild, do not port

**This is the central constraint on all subsequent work.** `fernandoaleman/dotfiles` is a *requirements document*, not source material. For every item the question is "how would someone who had only ever used Nix write this from scratch to produce the same behavior?" — never "how do I bring my existing shell code across."

Concretely this forbids: wrapping old files with `xdg.configFile."…".source = ./old-file`, reproducing the `conf.d/NN-name` numbering, and reaching for `initContent` where a home-manager module option exists.

The reason is not aesthetics. The repo already carries a scar from the previous migration — `conf.d/00-homebrew.zsh.tmpl` still opens with `Converted from yadm alternate: homebrew.zsh##o.Darwin,a.arm64`, two managers later. The finished repo should read as natively Nix-authored.

The corollary, applied before any module is written: **ask whether the thing is still needed at all.** The audit has already retired `create-ansible-docker-image` on these grounds, and roughly half of the ~200 shell aliases are expected not to survive it.

### One public repository

`fernandoaleman/nix-config` is **public**, so a bare machine can be brought up with `git clone` before any authentication exists. Nothing employer-specific is ever committed. This is achievable because the audit found the work-specific material is configuration *values*, not code:

| Item | Disposition |
|---|---|
| `aws-sso-login` | Rewritten to enumerate profiles via `aws configure list-profiles` rather than a hardcoded list |
| `aws-role-login` | Rewritten properly (the original's own header disowns it) |
| `generate-ssh-config` | Already discovers instances live; reads profiles the same way |
| SSH `config` | Only two home-LAN hosts and a wildcard; employer hosts live in the generated `~/.ssh/aws`, never committed |
| jira / confluence CLI configs | **Not managed.** Generated by `jira init` against one Atlassian instance; joins the secrets bucket |
| Secrets — SSH keys, AWS config, VPN profile, API tokens | Out of the repo entirely (see `plans/secrets.md`) |

The bootstrap ordering this buys is the point: clone public → `home-manager switch` → a working shell, editor, terminal and git → *then* authenticate and retrieve the private material.

### Repository layout

Named files, never numeric prefixes — following Omarchy's own convention in `plans/` and `bin/`.

```
flake.nix
flake.lock
plans/                 foundation.md, zsh.md, …
modules/               shared home-manager modules: zsh.nix, git.nix, terminals.nix, …
hosts/
  beelink/             Omarchy (Linux)
  <macbook>/           macOS (nix-darwin + home-manager)
```

Where bootstrap scripts are eventually needed, they follow Omarchy's `install/config/all.sh` shape: named scripts, sourced in order by one entry point — never `NN-` prefixes.

A `Makefile` is the repo's task runner. `just`, flake `apps` and a devShell are all common alternatives in Nix config repositories, but `make setup` has to run on a bare machine *before Nix exists* — installing `prek` and activating git hooks, which do not travel with a clone — so the entry point cannot depend on anything Nix provides. Make is universally present; `just` would itself need installing first. The Nix targets (`switch`, `build`, `check`, `update`, `generations`, `rollback`) are added once the flake exists and host output names are settled.

### `/nix` must be its own Btrfs subvolume

**Create it before installing Nix.** Omarchy ships snapper configured as:

```
SUBVOLUME="/"
NUMBER_LIMIT="5"
TIMELINE_CREATE="no"     # pre-update recovery only
```

If `/nix` lands on the root subvolume, all five snapshots retain nix-store state — a store is easily 10–40 GB — and a rollback from the limine boot menu would revert the store together with its SQLite database, silently undoing every package installed since. Relocating a populated `/nix` afterwards is painful; this is a one-shot decision at install time.

### The Omarchy boundary

Omarchy keeps these. Nix must not declare them:

- `~/.config/hypr/*.lua` — all six, plus `.luarc.json`
- `~/.config/omarchy/shell.json` and `omarchy/extensions/omarchy-menu.jsonc`
- `~/.config/omarchy/plugins/**` and `omarchy/themes/**` — nested git clones managed by `omarchy-plugin-*` and `omarchy-theme-update`
- `~/.local/state/omarchy/**` — generated theme state

The reason is mechanical. Omarchy's automatic config refresh is hash-guarded — `is_known_default_hash()` SHA-256s the file and only replaces it when it is byte-identical to a shipped default, so customized files are safe. Three paths bypass that guard:

- `always_copy_config_files` — unconditional copy, covering exactly the hypr Lua files, `shell.json` and the menu extension
- **17 of 116 migrations write in place** — 14 via `sed -i`, which replaces a symlink with a regular file; 3 via `cat "$tmp" > "$file"`, which writes *through* a symlink and fails `EROFS` against a read-only store path
- `omarchy-refresh-config` — `cp -f`, which unlinks and retries, silently replacing a symlink with a regular file

home-manager writes read-only store symlinks, so anything it owns inside that set will either be silently un-managed or hard-fail a migration. Outside that set the hash guard makes it safe.

## Verification before any module is written

These are inferences from reading the Omarchy tree, not observations on a live machine. Confirm on the Beelink first:

1. Does an interactive **zsh login shell** receive `OMARCHY_PATH`? The chain should be `/etc/zprofile` → `/etc/profile` → `/etc/profile.d/omarchy.sh` → `default/bash/env-bootstrap`, but this has not been observed.
2. Does the same shell receive Nix's PATH injection, and does `~/.nix-profile/bin` precede `/usr/bin`? `env-bootstrap` only ever *appends*, so Nix should keep precedence — unverified.
3. Confirm `/nix` is on its own subvolume and excluded from snapper before the first `nix build`.
4. Does `home-manager switch` collide with the `/etc/skel`-seeded `~/.config`? home-manager refuses to clobber unmanaged files, and Omarchy seeds the whole tree at user creation. Expect this on the first switch and record the resolution.

## Rollout

Omarchy first, macOS second. Omarchy is both the primary machine and the harder target; the Mac is forgiving and will receive modules already proven against a hostile environment. Work happens on a fresh Omarchy 4 install on a Beelink SER8, which carries only an SSH key and a personal `omarchy-aws-vpn-client` plugin — nothing to preserve, nothing to break.

The chezmoi repo stays untouched at `fernandoaleman/dotfiles` throughout. Both systems must work simultaneously: the Mac remains on chezmoi while Omarchy moves to Nix. Reverting is `chezmoi init fernandoaleman/dotfiles`.

Day-to-day rollback is Nix's own — `home-manager generations` and `--rollback`, with `flake.lock` pinning inputs. Git tags are for reference points, not recovery.

Sections follow in dependency order, each with its own plan: zsh, terminals, editor, git, tmux, CLI tools, packages, scripts, secrets, macOS, the Omarchy boundary, and bootstrap.

## Open questions

1. Reproducibility is a strong preference, not a hard requirement — which means the boundary is acceptable, but it should be stated in the repo README so future-me does not over-trust it. Two machines on the same flake but with different Omarchy migration histories are **not** identical; the flake pins the user environment, not the system.
2. `home.stateVersion` — pinning `26.05` or later makes `programs.zsh.dotDir` default to `${config.xdg.configHome}/zsh`, which is the desired XDG layout for free. Confirm against the home-manager revision actually pinned.
3. Does macOS need `nix-darwin` from day one, or is standalone home-manager enough until the macOS defaults section is reached?
4. Custom `.desktop` icons (six PNGs) need a home — shipped as files in the repo, or resolved from an icon theme. `xdg.desktopEntries.*.icon` accepts either.
5. **Default browser is Chrome, not Chromium.** Omarchy treats Chrome as first-class (`omarchy-install-browser`, and `omarchy-remove-browser` handles `google-chrome.desktop` explicitly), and both `omarchy-launch-browser` and `omarchy-launch-webapp` resolve the browser at runtime via `xdg-settings get default-web-browser` — so every web-app launcher inherits the default with no per-entry change. The native mechanism is `xdg.mimeApps.defaultApplications` for `x-scheme-handler/http`, `x-scheme-handler/https` and `text/html`. Omarchy's own `xdg-settings set default-web-browser chromium.desktop` runs once in `omarchy-provision-user`, before Nix exists, and `mimeapps.list` is on quattro's retired-config list, so there is no ongoing contention. **Open:** where Chrome comes from. It is unfree, so Nix needs `allowUnfree`; and a GUI Chrome on macOS is usually a Homebrew cask under `nix-darwin`. This may be a legitimate per-platform split under the "does not exist there" rule rather than the "distro already ships it" rule.
