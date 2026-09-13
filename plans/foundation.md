# Plan: Foundation — Nix + home-manager on Omarchy and macOS

Revision 2.

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

This is also why the two repositories are cloned differently. `nix-config` is cloned over **HTTPS**, which needs no credentials and is the whole reason it is public; the private reference repository requires SSH or a token and therefore presupposes authentication. Once keys exist on a machine, `make ssh` rewrites the origin remote in place — deriving the SSH URL from whatever HTTPS origin is set rather than hardcoding an account — replacing the old setup's `run_once_after_90-set-chezmoi-remote-ssh` script. Pushing over HTTPS also works once `gh auth login` has installed its credential helper, so this is a preference rather than a requirement.

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

**`modules/` is what runs on both machines; `hosts/<name>/` is what cannot.** That split is the mechanism for keeping Omarchy and the Mac as close to identical as possible, and it has a consequence worth stating plainly: every time a decision leans on something Omarchy already provides, it is also a decision that the Mac will not have it. Omarchy's shell layer, its aliases and functions, and its `mise`/`starship`/`zoxide`/`fzf` initialisation have no macOS equivalent. Leaning on them is a divergence, and it belongs under `hosts/beelink/` where it is visible as one.

Directory creation is **configuration, not a build task**. Directories that must exist in `$HOME` are declared through `home.activation` (with `lib.hm.dag.entryAfter` ordering) or `home.file`, never via a Makefile target or a bootstrap script — putting `mkdir -p` in the task runner would be a build step doing what the configuration system should declare. For a working directory such as `~/code`, an activation script is preferred over `home.file."code/.keep"`, so home-manager makes the directory exist without believing it owns the contents. Note also that `git clone` creates its full parent chain, so cloning into `~/code/nix-config` on a fresh machine creates `~/code` as a side effect.

A `Makefile` is the repo's task runner. `just`, flake `apps` and a devShell are all common alternatives in Nix config repositories, but `make setup` has to run on a bare machine *before Nix exists* — installing `prek` and activating git hooks, which do not travel with a clone — so the entry point cannot depend on anything Nix provides. Make is universally present; `just` would itself need installing first. The Nix targets (`switch`, `build`, `check`, `update`, `generations`, `rollback`) are added once the flake exists and host output names are settled.

Revision 1 conflated two audiences in one target. Arming git hooks is something *a contributor to this repo* does once per clone; it has nothing to do with bringing a machine up, and on a fresh install you do not need commit hooks before you need a shell. The two are split: `make setup` stays contributor tooling, and `make bootstrap` becomes the fresh-machine entry point. See [`bootstrap.md`](bootstrap.md).

### `/nix` must be its own Btrfs subvolume

**Create it before installing Nix.** Verified on the Beelink 2026-09-13: `/nix` did not exist and no `nix` binary was on PATH, so the decision was still open. Omarchy ships snapper configured as:

```
SUBVOLUME="/"
NUMBER_LIMIT="5"
TIMELINE_CREATE="no"     # pre-update recovery only
```

`/etc/snapper/configs/root` is byte-identical to the shipped `default/snapper/root`. `snapper-timeline.timer` is disabled, `snapper-cleanup.timer` enabled, and the only caller that creates a snapshot is `omarchy-snapshot create`, invoked by `omarchy-update` immediately before the package upgrade. "Pre-update recovery only" is an observation, not an inference.

If `/nix` lands on the root subvolume, all five snapshots retain nix-store state — a store is easily 10–40 GB — and a rollback from the limine boot menu would revert the store together with its SQLite database, silently undoing every package installed since. Relocating a populated `/nix` afterwards is painful; this is a one-shot decision at install time.

The exclusion works because **Btrfs snapshots do not recurse into nested subvolumes**. Omarchy states this in its own source — `omarchy-system-factory-reset:257`, explaining why a restored factory root carries only an empty `/swap` directory where the hibernation swapfile lived.

#### Top-level `@nix`, not a nested `/nix`

The Beelink's layout is four top-level subvolumes on one LUKS-backed Btrfs filesystem, each mounted by an fstab `subvol=` entry — `@` at `/`, `@home`, `@log`, `@pkg` — plus one *nested* subvolume, `/swap`, created inside `@` by `omarchy-hibernation-setup` with no fstab entry at all. So Omarchy itself demonstrates both placements, and `/nix` could take either. Both keep the store out of snapshots. They differ on **restore**, and that decides it.

`/etc/limine-snapper-sync.conf` sets `RESTORE_METHOD=replace`, which that file documents as *"creates a new subvolume from a selected snapshot and replaces the old one"*. Strings in `/usr/lib/limine/limine-snapper-sync` show it copes with nested subvolumes by enumerating `btrfs subvolume list -o` and moving them across, keeping the old root as a *"backup subvolume"* — with a `"Failed to moved the child subvolumes."` error path. A nested `/nix` would therefore *probably* survive a restore, by way of undocumented behaviour in a third-party tool that has a failure mode.

A top-level `@nix` is not a child of `@` at all, so nothing has to move it: `@` can be replaced freely and the fstab entry — restored from any snapshot taken after `@nix` was created — remounts it. It also matches the `@home`/`@log`/`@pkg` convention rather than the `/swap` exception. `@pkg` is the closest precedent: a large, regenerable cache given its own subvolume for exactly this reason. `@nix` is its direct analogue.

The one cost is that a top-level `@nix` survives `omarchy-system-factory-reset` as an orphan subvolume rather than vanishing with the old root. That matters only when handing the machine on, and is one `btrfs subvolume delete` to clean up. Recorded here so it is not rediscovered as a surprise.

Two further points, both verified rather than assumed:

- **The official Nix installer supports a pre-existing `/nix`.** `scripts/install-multi-user.sh:655` — `if [ -d "$NIX_ROOT" ]; then` … *"if /nix already exists, take ownership"* — and `validate_starting_assumptions` makes no claim about `/nix`. Pre-creating the mount is the supported path, not a workaround.
- **`/nix` must be added to `updatedb.conf`'s `PRUNEPATHS`.** Omarchy deliberately sets `PRUNE_BIND_MOUNTS = "no"` in `install/config/locate.sh` so that subvolume mounts like `/home` get indexed; without pruning, `plocate-updatedb.timer` would index millions of store paths nightly. That script only rewrites `PRUNEPATHS` when `/.snapshots` is missing from it, and preserves existing entries when it does, so the addition is durable across updates and migrations.

Commands, ordering and the rest of the first-boot sequence are in [`bootstrap.md`](bootstrap.md).

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

### The theme system is *not* part of that boundary

Checked on 2026-09-13, because it looked like it would be. Omarchy's theming renders templates from `default/themed/` and `~/.config/omarchy/themed/` — 17 of them, covering alacritty, btop, foot, ghostty, kitty, neovim, helix, chromium and more — but `omarchy-theme-set-templates:393` writes every one of them to `$NEXT_THEME_DIR`, which is `~/.local/state/omarchy/current/next-theme`. **Nothing in the theme pipeline writes into `~/.config`.**

The configs in `~/.config` *reference* that state instead:

```
alacritty.toml:  general.import = [ "~/.local/state/omarchy/current/theme/alacritty.toml" ]
btop.conf:       color_theme = "current"
```

So home-manager can own `~/.config/alacritty/alacritty.toml`, `btop.conf`, the terminal configs and `starship.toml` — `starship.toml` freely, since no template targets it, and the others provided the import line is preserved. That is a much narrower boundary than assumed, and it unblocks the terminals section.

One exception, found by grepping every `omarchy-theme-set-*` for writes under `$HOME/.config`: **`omarchy-theme-set-vscode`** writes `~/.config/Code/User/settings.json`, and the Cursor and VSCodium equivalents. Not relevant while the editor is neovim, but it belongs on the list.

## Verification before any module is written

Worked on the Beelink, 2026-09-13, against a fresh Omarchy Quattro install. Two of the four assumptions were wrong. Findings below; the evidence is cited so a future reader can re-check it rather than trust this document.

### 1. Does a zsh login shell receive `OMARCHY_PATH`? — **premise was wrong**

The question cannot be asked as written. **zsh is not installed** (`pacman -Q zsh` → not found) and the login shell is `/usr/bin/bash` (`getent passwd`). None of `/etc/zprofile`, `/etc/zshenv`, `/etc/zsh/zprofile` or `/etc/zsh/zshrc` exist, `/etc/shells` lists no zsh, and `zsh` appears nowhere in Omarchy's package lists. Revision 1 also had the path wrong: Arch's zsh package ships that file at `/etc/zsh/zprofile`, not `/etc/zprofile`.

What *was* confirmed, on the bash login path (`env -i bash -lc`): `/etc/profile.d/omarchy.sh` sources `default/bash/env-bootstrap`, which exports `OMARCHY_PATH=/usr/share/omarchy` and appends `~/.local/share/mise/shims` and `~/.local/bin` to PATH. The "only ever appends" claim is confirmed by reading and by the resulting PATH.

This stops being a verification item and becomes a design question for [`zsh.md`](zsh.md): **where does zsh come from?** If home-manager's `programs.zsh` pulls zsh from nixpkgs, the Arch package is never installed, `/etc/zsh/zprofile` never exists, and a zsh login shell gets no `OMARCHY_PATH` and none of `/etc/profile` at all. The store path would also need to be in `/etc/shells` before `chsh` accepts it. Two sub-questions, neither yet checked: what `etcdir` nixpkgs builds zsh with, and whether the right answer is to install the pacman `zsh` purely for its `/etc/zsh/zprofile` or to source `env-bootstrap` from `programs.zsh.envExtra` directly. The latter is more in keeping with "rebuild, do not port".

### 2. Does Nix keep PATH precedence over `/usr/bin`? — **confirmed, observed**

Predicted structurally, then observed on a login shell after installing Nix on 2026-09-13:

```
1  /home/faleman/.nix-profile/bin
2  /nix/var/nix/profiles/default/bin
3  /usr/local/sbin
4  /usr/local/bin
5  /usr/bin
6  /home/faleman/.local/share/mise/shims
7  /home/faleman/.local/bin
```

Nix takes the first two positions and `/usr/bin` is fifth, so the answer is yes with room to spare. The mechanism is the one predicted: `/etc/profile` runs its `append_path '/usr/bin'` calls *before* the `/etc/profile.d/*.sh` loop, `nix.sh` then *prepends*, and `env-bootstrap` only ever appends — mise shims and `~/.local/bin` land at 6 and 7. `nix.sh` also happens to sort before `omarchy.sh`, but the outcome does not depend on that.

One side effect worth noting: `~/.local/bin` now sits *after* `/usr/bin` rather than before it, because removing prek's `env` script removed the only thing that prepended it. Nothing on this machine shadows anything in `~/.local/bin`, so this is a non-issue today — but it is the kind of thing that turns into a confusing afternoon later, so it is written down.

### 3. `/nix` on its own subvolume — **resolved, see above**

Resolved in full: `/nix` did not exist, the decision was open, and the chosen design is a top-level `@nix`. Rationale and evidence are in "`/nix` must be its own Btrfs subvolume"; commands are in [`bootstrap.md`](bootstrap.md).

### 4. Does `home-manager switch` collide with the `/etc/skel`-seeded `~/.config`? — **yes, but narrower than feared**

`/etc/skel` holds 8,068 files and did seed `~/.config` at user creation. But every skel-derived config file compared is **byte-identical to skel** — `alacritty/alacritty.toml`, `btop/btop.conf`, `foot/foot.ini`, `ghostty/config`, `kitty/kitty.conf`, `lazygit/config.yml`, `tmux/tmux.conf`, `starship.toml`. Only `~/.config/git/config` differs, and `omarchy/shell.json`, which is Omarchy-owned per the boundary anyway.

home-manager does not hash-compare against skel — it refuses any existing unmanaged file in the way — so the first switch will still fail on each of these. The resolution is cheap precisely because nothing is being lost: `home-manager switch -b bak`, or delete the identical-to-skel files first. `~/.config/git/config` is the only one needing a real merge.

**Resolved in practice on 2026-09-13**, when `modules/git.nix` became the first module to write into `~/.config`. Exactly two collisions, both anticipated: `~/.config/git/config` (skel-seeded, later modified by `gh auth login`) and `~/.config/gh/config.yml`. `home-manager switch -b bak` renamed both to `.bak` and linked the store paths over them — no data lost, and the backups are still there to diff against. Nothing else in the tree was touched.

The lesson worth keeping is that the collision set is not "everything skel seeded", it is "the files a module actually declares". With one module it was two files, and `-b bak` on that one switch was the whole resolution.

One wrinkle this turned up, caused by this repo rather than by Omarchy: `make setup` piped prek's installer to `sh`, and that installer wrote `~/.zshrc`, `~/.profile`, `~/.config/fish/conf.d/prek.env.fish` and appended to `~/.bashrc` and `~/.bash_profile`. Cause and fix are in [`bootstrap.md`](bootstrap.md). Whether the stray `~/.zshrc` is an outright collision depends on `programs.zsh.dotDir`: with the XDG default it is merely dead, misleading cruft that never loads; if `dotDir` ever resolves to `$HOME` it becomes a real collision. Either way it should not be there.

## Rollout

Omarchy first, macOS second. Omarchy is both the primary machine and the harder target; the Mac is forgiving and will receive modules already proven against a hostile environment. Work happens on a fresh Omarchy 4 install on a Beelink SER8, which carries only an SSH key and a personal `omarchy-aws-vpn-client` plugin — nothing to preserve, nothing to break.

The chezmoi repo stays untouched at `fernandoaleman/dotfiles` throughout. Both systems must work simultaneously: the Mac remains on chezmoi while Omarchy moves to Nix. Reverting is `chezmoi init fernandoaleman/dotfiles`.

Day-to-day rollback is Nix's own — `home-manager generations` and `--rollback`, with `flake.lock` pinning inputs. Git tags are for reference points, not recovery.

Sections follow in dependency order, each with its own plan: zsh, terminals, editor, git, tmux, CLI tools, packages, scripts, secrets, macOS, the Omarchy boundary, and bootstrap.

## Open questions

1. ~~Reproducibility is a strong preference, not a hard requirement — which means the boundary is acceptable, but it should be stated in the repo README so future-me does not over-trust it.~~ **Resolved 2026-09-13:** stated in the README under "What this does and does not pin". Two machines on the same flake but with different Omarchy migration histories are **not** identical; the flake pins the user environment, not the system.
2. `home.stateVersion` — pinning `26.05` or later makes `programs.zsh.dotDir` default to `${config.xdg.configHome}/zsh`, which is the desired XDG layout for free. Confirm against the home-manager revision actually pinned. Note that `stateVersion` is not a preference dial: it declares which release's default *behaviour* the configuration was written against, so it is chosen once and then left alone.
3. Does macOS need `nix-darwin` from day one, or is standalone home-manager enough until the macOS defaults section is reached?
4. Custom `.desktop` icons (six ONGs) need a home — shipped as files in the repo, or resolved from an icon theme. `xdg.desktopEntries.*.icon` accepts either.
5. **Default browser is Chrome, not Chromium.** Omarchy treats Chrome as first-class (`omarchy-install-browser`, and `omarchy-remove-browser` handles `google-chrome.desktop` explicitly), and both `omarchy-launch-browser` and `omarchy-launch-webapp` resolve the browser at runtime via `xdg-settings get default-web-browser` — so every web-app launcher inherits the default with no per-entry change. The native mechanism is `xdg.mimeApps.defaultApplications` for `x-scheme-handler/http`, `x-scheme-handler/https` and `text/html`. Omarchy's own `xdg-settings set default-web-browser chromium.desktop` runs once in `omarchy-provision-user`, before Nix exists, and `mimeapps.list` is on quattro's retired-config list, so there is no ongoing contention. **Open:** where Chrome comes from. It is unfree, so Nix needs `allowUnfree`; and a GUI Chrome on macOS is usually a Homebrew cask under `nix-darwin`. This may be a legitimate per-platform split under the "does not exist there" rule rather than the "distro already ships it" rule.
6. ~~Which Nix installer.~~ **Resolved 2026-09-13:** `NixOS/nix-installer`, the NixOS Foundation's fork of the Determinate installer — upstream Nix, first-class handling of a pre-mounted `/nix`, and an uninstall that empties the subvolume without unmounting it. Full comparison and the three rejected alternatives are in [`bootstrap.md`](bootstrap.md).
