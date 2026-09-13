# Plan: Bootstrap — a fresh Omarchy install to a working machine

Revision 1. Depends on [`foundation.md`](foundation.md).

## Problem

The goal is a brand-new Omarchy Quattro install reaching a working, configured machine in as few commands as possible, repeatably, years from now, without anyone having to remember an undocumented step.

Three things make that harder than "clone and switch":

- **One step is irreversible and must happen first.** `/nix` has to be its own Btrfs subvolume *before* Nix is installed, or the store lands on `@` and every Snapper rollback silently reverts it. It needs root, and it cannot be deferred or retried cheaply once the store is populated. See foundation.md, "`/nix` must be its own Btrfs subvolume".
- **The repository is public precisely so it can be cloned before authentication exists**, which fixes the ordering: clone over HTTPS → working shell, editor, terminal, git → *then* authenticate and fetch the private material. Anything that needs a key cannot be part of the bootstrap.
- **Revision 1 of foundation.md conflated two audiences.** `make setup` was described as the thing you run "on a bare machine", but what it actually does — install `prek` and arm git hooks — is what a *contributor to this repo* does once per clone. On a fresh machine you need a shell before you need a commit-message linter.

## Rejected approaches

- **One `make setup` doing everything.** This is what revision 1 implied. It fails the audience test in both directions: a fresh machine is made to install commit hooks it has no use for, and a second clone on an already-provisioned machine is offered a `/nix` subvolume step that would be wrong to run. Worse, it puts a `sudo` prompt in the path of a target whose job is arming git hooks.
- **A `curl | bash` bootstrap from a gist or a raw URL.** The usual shape for "one command", and rejected because this repository *is* the artifact. A pipe-to-shell URL is a second, unversioned copy of the bootstrap that drifts from the repo it installs, and it cannot be reviewed before it runs. `git clone` first is one extra command and the whole thing is then on disk and inspectable.
- **Putting `/nix` subvolume creation in `home.activation`.** Forbidden by ordering, not by taste: `home.activation` runs under home-manager, which needs Nix, which needs `/nix` to already be a subvolume. It is also root-level and system-level, which `home.activation` is not.
- **Cleaning up after prek's installer instead of preventing it.** See "Shell rc pollution" below. Cleanup cannot distinguish the lines the installer added from lines the user wants, is not idempotent, and leaves the bug in place for the next machine.

## Chosen design

### Two entry points, by audience

| Target | Audience | Needs root | Runs when |
|---|---|---|---|
| `make bootstrap` | A fresh machine | Yes, for the subvolume | Once per machine |
| `make setup` | Someone editing this repo | No | Once per clone |

They are independent. A fresh machine that will also be used for development runs both; a machine that only consumes the config runs only `bootstrap`; a second clone on an existing machine runs only `setup`.

The "fewest commands" target is therefore two:

```sh
git clone https://github.com/fernandoaleman/nix-config ~/code/nix-config
cd ~/code/nix-config && make bootstrap
```

`git clone` creates its full parent chain, so `~/code` exists as a side effect and needs no separate step — the same observation that removed the old `create-dirs` bootstrap script.

### What `make bootstrap` does, in order

Following foundation.md's convention — named scripts sourced in order by one entry point, in the shape of Omarchy's `install/config/all.sh`, never `NN-` prefixes.

1. **`nix-subvolume`** — create the top-level `@nix` subvolume, add its fstab entry, mount it, and add `/nix` to `updatedb.conf`'s `PRUNEPATHS`. Root. Idempotent: does nothing if `/nix` is already a mountpoint.
2. **`nix-install`** — run the Nix installer. Root. Idempotent: does nothing if `nix` is already on PATH.
3. **`switch`** — `home-manager switch --flake .#<host>`. Not root. This is the step that is run again and again afterwards; the first run is just the first of many.

Step 1 is the only place the bootstrap asks for `sudo`, and it is the only step that cannot be undone cheaply — so it is first, it is loud about what it is doing, and it refuses to guess.

### Step 1 in full

Recorded here because it is a one-shot, root-level, irreversible step and the reasoning behind each flag matters more than the commands.

```sh
# Create @nix alongside @, @home, @log, @pkg at the filesystem top level.
sudo mount -o subvolid=5 /dev/mapper/root /mnt
sudo btrfs subvolume create /mnt/@nix
sudo umount /mnt
sudo mkdir -p /nix
```

Then the fstab entry, alongside the existing four and using the same filesystem UUID:

```
UUID=<root-uuid>	/nix	btrfs	rw,noatime,compress=zstd:3,ssd,space_cache=v2,subvol=/@nix	0 0
```

followed by `sudo systemctl daemon-reload && sudo mount /nix`, and `findmnt /nix` to confirm.

Why each option:

- **`subvol=/@nix`, top level** — not a nested subvolume inside `@`. The reasoning is in foundation.md; the short version is that `RESTORE_METHOD=replace` has to *move* nested subvolumes into the replacement root, and a sibling never has to be moved at all.
- **`noatime`** rather than the `relatime` the other four use — the store is a large, read-mostly tree of immutable files. Access-time updates are pure write amplification here and buy nothing.
- **`compress=zstd:3`** kept, matching the rest of the filesystem. The store is highly compressible and this is a straight win.
- **Normal CoW, no `nodatacow`** — `nodatacow` would cost checksums *and* compression to avoid fragmentation that a write-once store does not suffer from.

And the locate exclusion, which is easy to forget and expensive to discover:

```sh
# PRUNE_BIND_MOUNTS = "no" is deliberate in Omarchy, so subvolume mounts get
# indexed. Without this, plocate-updatedb.timer indexes the whole store nightly.
```

`/nix` is appended to the existing `PRUNEPATHS` value rather than replacing it. Omarchy's `install/config/locate.sh` only rewrites that setting when `/.snapshots` is absent from it, and preserves existing entries when it does, so the addition survives updates and migrations.

### Which Nix installer

**Chosen: [`NixOS/nix-installer`](https://github.com/NixOS/nix-installer)**, the NixOS Foundation's fork of the Determinate Nix Installer, which installs upstream Nix and nothing else.

```sh
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes --no-confirm
```

Four candidates were weighed. The decision turns on one hard requirement — it must accept the pre-created `@nix` mount from step 1 — and one soft one: Nix is a *guest* on Omarchy, so it has to be removable without leaving wreckage.

| Installer | Upstream Nix | Pre-mounted `/nix` | Uninstall | Verdict |
|---|---|---|---|---|
| `NixOS/nix-installer` | Yes | First-class | `/nix/nix-installer uninstall` | **Chosen** |
| Determinate Nix Installer | No, not since 2026-01-01 | First-class | `/nix/nix-installer uninstall` | Rejected |
| `nixos.org/nix/install` | Yes | Tolerated | Manual, documented | Rejected |
| Arch `extra/nix` | Yes | n/a | `pacman -R` | Rejected |

**Why the fork wins the mount question.** Its `CreateDirectory` action checks whether the path is already a mountpoint and short-circuits, with a comment naming our exact case:

```rust
if *is_mountpoint {
    // A `/nix` mount exists, we don't need to do anything.
    return Ok(());
}
```

`/nix` is planned as `CreateDirectory::plan("/nix", None, None, 0o0755, true)` — `None` for user and group, so the ownership checks that guard other paths are skipped entirely, and `sudo mkdir -p /nix` (root:root, 0755) matches the requested mode anyway. The trailing `true` is `force_prune_on_revert`, which on uninstall selects the `(is_mountpoint, _, true)` branch: it empties the directory and **leaves the mount in place**. So `uninstall` returns the `@nix` subvolume to empty without touching fstab — exactly the behaviour wanted, and it means a botched install can be backed out without redoing step 1.

**Why not the Determinate Nix Installer**, despite being the better-known tool and the origin of the code above. Since 2026-01-01 it installs only [Determinate Nix](https://docs.determinate.systems/determinate-nix), a downstream *distribution* with proprietary additions and a bundled `determinate-nixd` daemon; the `--prefer-upstream-nix` escape hatch was announced as non-functional from that date. That is a defensible product, but it is a vendor distribution at the very bottom of the stack, in a repository whose stated thesis is a configuration that "reads as though it were natively Nix-authored" and whose only other vendor dependency is the OS itself. Determinate Systems point people who want upstream Nix at this fork, so taking it is following their own advice rather than working against the tool.

**Why not `nixos.org/nix/install`.** It works: `scripts/install-multi-user.sh:655` takes ownership of a pre-existing `/nix`, and `validate_starting_assumptions` makes no contrary claim. But that is incidental tolerance rather than the deliberate mountpoint handling above; it is the shell installer whose maintenance problems motivated the Rust rewrite in the first place; and it has no uninstall beyond a documented manual procedure. The fork is a superset on every axis that matters here.

**Why not Arch's `extra/nix`.** Tempting — it is one `pacman -S nix`, currently 2.35.2, the same upstream version the fork installs, packaged by an Arch maintainer. It is rejected because it would put Nix under `pacman`, and therefore under `omarchy-update`. Step 1 of this bootstrap exists precisely to *disentangle* the Nix store from Omarchy's update-and-rollback machinery; installing Nix itself as a pacman package re-entangles them at a different layer, and a `pacman -Syu` could move the Nix version underneath a working generation. It is also Linux-only, so the Mac would bootstrap by a different mechanism.

**Maintenance check, since "experimental" appears in the fork's old name.** It is not experimental in practice: the repository is now `NixOS/nix-installer` under the NixOS org, LGPL-2.1, releases are versioned to the Nix they install, and 2.35.2 shipped 2026-09-12 — the day before this was written. Recent commits include active macOS APFS work. Linux `x86_64` multi-user via systemd is listed Stable; macOS is Stable on `aarch64`.

**Flakes are not on by default** in upstream Nix, hence `--enable-flakes`. This writes `nix.conf` at install time; once home-manager owns the user environment, `nix.settings` is the better home for it, and the flag only has to get the bootstrap far enough to run the first switch.

#### State on the Beelink

Step 1 was carried out on 2026-09-13 and verified:

```
/nix   /dev/mapper/root[/@nix]   rw,noatime,compress=zstd:3,ssd,subvolid=268,subvol=/@nix
```

`subvol=/@nix`, not `/@/nix` — a sibling of `@`, `@home`, `@log` and `@pkg`, which is what puts it structurally out of reach of any snapshot of `@`. `root:root`, mode `0755`, empty. `findmnt --verify` reports no errors, `systemd-fstab-generator` has produced a `nix.mount` that is `RequiredBy=local-fs.target`, so it remounts on boot. `/nix` is appended to `PRUNEPATHS` with `/.snapshots` preserved.

Step 2 followed on the same day, with `NixOS/nix-installer` 2.35.2 installing upstream Nix 2.35.2. Verified afterwards: `findmnt -T /nix/store` resolves to `/dev/mapper/root[/@nix]`, so the store is genuinely on the subvolume rather than on `@`; `/nix` is a single mount layer on subvolid 268; `/nix/nix-installer` and `/nix/receipt.json` exist, so `uninstall` is available; `nix-daemon.service` and `.socket` are active with 32 `nixbld` build users; and `nix config show` reports `experimental-features = fetch-tree flakes nix-command`.

Two things left behind, neither urgent:

- ~~The fstab line omits the sixth field.~~ Fixed the same day; `findmnt --verify` reports `0 parse errors, 0 errors`. While fixing it the mount was briefly stacked two deep — `mount` run a second time over an already-mounted `/nix` — which is harmless but is not the state a fresh boot produces. Popped with one `umount`. Worth knowing that `grep -c ' /nix ' /proc/self/mountinfo` is the quick check, and that it must read exactly `1`: at `0`, an install would put the store on `@`.
- **The five existing Snapper snapshots predate the fstab change.** Restoring one of them yields a root whose fstab has no `/nix` line, so `/nix` would not mount at boot and Nix would look wiped. The subvolume itself is untouched — it is a sibling, not a child — so the repair is to re-add the one fstab line. This self-heals as soon as `omarchy-update` rotates a fresh snapshot in, and it is the mirror image of the property that makes a top-level `@nix` the right choice in the first place.

### Shell rc pollution: prevent, do not clean up

`make setup` pipes prek's installer to `sh`. On 2026-09-13 that installer wrote `~/.zshrc` and `~/.profile`, created `~/.config/fish/conf.d/prek.env.fish`, appended a `source` line to `~/.bashrc` and `~/.bash_profile`, and dropped `~/.local/bin/env` and `env.fish`.

The cause is specific and worth recording, because it looks like the installer being careless and is not. cargo-dist's installer has a guard meant to skip all of that when its install directory is already on PATH:

```sh
case :$PATH:
  in *:$_install_dir:*) NO_MODIFY_PATH=1 ;;
```

`$XDG_DATA_HOME` is set on Omarchy, so the installer resolves its install directory to `$XDG_DATA_HOME/../bin` — the literal, unnormalised string `/home/<user>/.local/share/../bin`. Omarchy's `env-bootstrap` appends the *normalised* `/home/<user>/.local/bin`. Same directory, different spelling, string match fails, guard misses, and it writes to all five files.

The fix is `PREK_NO_MODIFY_PATH=1` on the pipe. `~/.local/bin` is already on PATH on Omarchy via `env-bootstrap`, and on macOS prek comes from Homebrew, so suppressing the rc edits loses nothing on either target. Verified against a throwaway `$HOME`: with the variable set, the installer creates only `~/.local/bin/prek` and `~/.config/prek/prek-receipt.json`.

Cleaning up afterwards was considered and rejected. It would have to distinguish the installer's lines from the user's, it would run on every `make setup` rather than once, and it would leave the next fresh machine to hit the same thing.

This is also a general rule for this repository, not a one-off: **a bootstrap step that writes outside its own install prefix is a bug to be suppressed, not a mess to be tidied.** Anything that belongs in a shell rc belongs in a home-manager module.

## Open questions

1. ~~Which Nix installer.~~ **Resolved 2026-09-13:** `NixOS/nix-installer`, for the reasons under "Which Nix installer" above. The fork dropped `x86_64-darwin` on 2026-07-14; confirmed not to matter, as every Mac in play is Apple Silicon, which the fork lists as Stable.
2. **`trusted-users` is `root` only.** The installer leaves the invoking user untrusted, which is fine against `cache.nixos.org` and therefore fine for everything planned so far. It starts to matter the moment a flake declares `extra-substituters` — the nix-community cache is the usual case for home-manager users — because an untrusted user's substituter requests are silently ignored rather than refused. The natural home for the setting is `/etc/nix/nix.custom.conf`, which the installer creates empty and reserves for exactly this. Note that this is *outside* the repo: on non-NixOS Linux, home-manager does not manage `/etc/nix/nix.conf`, so if this is wanted it becomes a fourth bootstrap step rather than a module option.
3. **Does `make bootstrap` run `switch` at all on its first pass?** The flake needs a host output name, and the host is the machine being bootstrapped. Either the host is detected from `hostname`, or the first switch is a separate explicit command. Detection is tidier and is one more thing to go wrong silently.
4. **Where does the `/etc/skel` collision resolution live?** `home-manager switch -b bak` as a flag in the Makefile target makes the first switch succeed unattended, but it also silently backs up files on *every* subsequent switch that hits a collision, which is a failure worth seeing. Possibly first-run only.
5. **Does the bootstrap need a reboot?** Nothing in the sequence obviously requires one — the `@nix` mount is live after `mount /nix`, and the Nix daemon starts on install. Confirm rather than assume, and if a reboot is needed, say so at the end of the run rather than leaving the machine half-configured.
6. **`chsh` to a Nix-provided shell** needs the store path in `/etc/shells` and is root-level, so if zsh comes from Nix this becomes a fourth bootstrap step. Blocked on the zsh sourcing question in [`zsh.md`](zsh.md).
