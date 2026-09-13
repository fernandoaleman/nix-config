# Plan: git — configuration, aliases and the Omarchy overlap

Revision 1. Depends on [`foundation.md`](foundation.md); its "Rebuild, do not port" constraint governs everything here.

## Problem

git is the first module where three sources of configuration meet and have to be reconciled rather than merely translated:

- **Omarchy ships a git config** at `/usr/share/omarchy/config/git/config`, seeded into `~/.config/git/config` via `/etc/skel`. It is not just aliases — it carries `rerere`, `diff.algorithm`, `column.ui`, `branch.sort`, `tag.sort`, `push.autoSetupRemote`, `pull.rebase` and `commit.verbose`.
- **The reference setup** (`fernandoaleman/dotfiles`) has its own `config.tmpl` plus **79 git aliases** among the 137 in `conf.d/50-aliases.zsh.tmpl`, a `gitignore`, a `gitmessage` template, and a `git_template/hooks/prepare-commit-msg`.
- **`gh auth login` has written to the same file**, adding credential helpers.

home-manager's `programs.git` *replaces* `~/.config/git/config` rather than merging into it, so anything from those three not consciously carried across disappears on the first switch. That makes this an audit, not a port.

The aliases also collide. Omarchy defines `ga` and `gd` as **shell functions**, not aliases — easy to miss when grepping for `alias` — and they are worktree helpers:

| Name | Omarchy | Reference setup | Severity |
|---|---|---|---|
| `gd` | removes the current worktree *and its branch*, behind a `gum confirm` | `git diff --color=always` | **Dangerous** |
| `ga` | creates worktree `../base--branch`, mise-trusts it, cds in | `git add` | High |
| `gcm` | `git commit -m` | `git checkout master` | High |
| `g` | `git` | `git` | None — identical |

`gd` is the one that matters. Twenty years of `gd` meaning "show me the diff", typed reflexively, lands on a prompt to delete a worktree and a branch — and reflex is exactly the state in which people do not read prompts.

## Rejected approaches

- **`programs.git.settings.alias` *and* keeping the 79 shell aliases.** Would mean picking a winner for `ga`, `gd` and `gcm` on every machine forever, and silently losing an Omarchy feature each time. Rejected on the collision table above.
- **Keeping the aliases in `shellAliases`, renaming the three that clash.** Trades a working Omarchy feature for muscle memory, and the renames would themselves be new names to learn — the cost of moving to `g d` without the benefit.
- **`programs.git.hooks` for the `prepare-commit-msg` hook.** Verified in the pinned home-manager source (`modules/programs/git.nix:511`): it sets `core.hooksPath`, which overrides `.git/hooks` **globally, for every repository**. That would silently disable the `prek` hooks this repo installs via `make setup`, along with any other per-repo hook. Wrong tool; `init.templatedir` keeps the original per-repo-at-clone-time semantics.
- **Porting the `[delta]` blocks verbatim.** `programs.delta` takes the same keys as an attrset and, with `enableGitIntegration = true`, writes `core.pager` and `interactive.diffFilter` itself, so the two lines that existed to connect delta to git are deleted rather than translated. Note that the option defaults to `false`; assuming otherwise produces a config that installs delta and never uses it.

## Chosen design

One `modules/git.nix`. Aliases live in **`programs.git.settings.alias`**, not `shellAliases`.

Because Omarchy already aliases `g` to `git`, `g d` gives the diff while Omarchy's `gd` worktree helper keeps working. The two namespaces stop competing entirely. The cost is one space; the gain is completion for free, and aliases that work in scripts, in `sh`, and over SSH where the zsh config is not loaded.

**The git-subcommand namespace has no conflicts at all.** Omarchy's four aliases and the reference setup's six overlap on three names and agree on all three: `co` = `checkout` in both, `st` = `status` in both, and `ci` is `commit` versus `commit -v` — equivalent, because Omarchy sets `commit.verbose = true` globally. git also refuses to let an alias shadow a builtin, so the namespace is self-protecting in a way the shell namespace is not.

### Option names verified against the pinned revision

home-manager master has renamed these, and the old spellings only survive as deprecation shims. Checked in `/nix/store/…-source/modules/programs/git.nix` at the revision in `flake.lock`, not in documentation:

| Old spelling | Native spelling |
|---|---|
| `programs.git.extraConfig` | `programs.git.settings` |
| `programs.git.userName` | `programs.git.settings.user.name` |
| `programs.git.userEmail` | `programs.git.settings.user.email` |
| `programs.git.aliases` | `programs.git.settings.alias` |

Writing `programs.git.aliases` would work and warn. It is also exactly the kind of stale idiom this repository exists to not carry forward.

### The audit

Omarchy's settings, kept unless noted — they are good defaults and dropping them would be a silent regression:

| Setting | Disposition |
|---|---|
| `init.defaultBranch = master` | **Keep.** Omarchy and the reference setup already agree |
| `pull.rebase`, `push.autoSetupRemote` | **Keep** |
| `diff.algorithm = histogram`, `diff.mnemonicPrefix` | **Keep** |
| `diff.colorMoved` | **Rebuild.** Omarchy says `plain`, the reference setup says `zebra`. `zebra` distinguishes moved-and-modified from moved-verbatim; take it |
| `commit.verbose` | **Keep** — and it makes the reference setup's `ci = commit -v` redundant |
| `column.ui`, `branch.sort`, `tag.sort`, `rerere.*` | **Keep** |

From the reference setup:

| Setting | Disposition |
|---|---|
| `user.name` / `user.email` | **Keep, committed.** The identity in use is a personal address already public in this repository's own commit history. Work identity is a `gitdir:` conditional include pointing outside the repo — see `secrets.md` |
| `core.excludesfile` + `gitignore` | **Rebuild** as `programs.git.ignores`, a list rather than a file |
| `core.autocrlf = input` | **Keep.** Correct on both targets |
| `core.pager = delta`, `interactive.diffFilter`, `[delta]` blocks | **Rebuild** as `programs.delta` with `enableGitIntegration = true`. That option defaults to **false** — without it delta is installed and styled but git never calls it. The two wiring lines are deleted; the styling survives as `options` |
| `fetch.prune`, `rebase.autosquash`, `merge.conflictstyle = zdiff3` | **Keep** |
| `push.default = current` | **Drop.** Redundant beside `push.autoSetupRemote`, and git's own `simple` default is the safer of the two |
| `color.ui = true` | **Drop.** git has defaulted to `auto` since 1.8.4; this line has been a no-op for a decade |
| `init.templatedir` + `prepare-commit-msg` | **Rebuild.** The hook is generic — it extracts `[A-Z]+-[0-9]+` from the branch name — so only its example comment was work-specific. Rebuilt as a store path, keeping `init.templatedir` rather than `core.hooksPath` for the reason under Rejected approaches |
| `git_template/info/exclude` | **Drop.** Comments only |
| `commit.template` + `gitmessage` | **Keep**, rebuilt inline — but see open questions |
| `gh` credential helpers | **Rebuild** as `programs.gh`. The current entries hardcode `~/.local/share/mise/installs/gh/2.100.0/…/gh`, a version-pinned path that breaks on the next `mise up`. `programs.gh.gitCredentialHelper.enable` defaults to `true` and covers both `github.com` and `gist.github.com` |

### The alias trim: 79 → 15

Three buckets, not two.

**Dissolved — the requirement is gone (13).** `ggpush`, `ggpull`, `ggpnp`, `ggpur`, `ggpurt`, `gupush`, `gupur` all exist to paper over `$(current_branch)`; `push.autoSetupRemote` is set and bare `git push` has done the right thing for years. `gfum`, `grum`, `gfrum`, `gft`, `gftf` serve an upstream-fork workflow. `gcl` is `git config --list`. These are not trimmed for taste — what produced them no longer exists.

**Moves to zsh (1).** `grt` is `cd $(git rev-parse --show-toplevel)`. It mutates shell state, so by zsh.md's own rule it stays a shell function and is handed to that module.

**Dropped as unused (50).** The stash family alone is eleven aliases for a command already three characters long; `gcs` and `grbs` are multi-step shell one-liners with temporary variables; `gcount`, `gwc`, `gscp`, `gmt`, `gf` are rare. `grep` is not a git alias at all — it shadows the binary with `--color=always` and goes.

**Kept (15).** Seven are the uncontested core already present in *both* existing git configs, so they are not a new invention:

```
aa = add --all          ap = add --patch        br = branch
ci = commit -v          co = checkout           pf = push --force-with-lease
st = status
```

Eight promoted from the shell aliases, where the requirement still stands:

```
amend = commit -v --amend               d  = diff
dc    = diff --cached                   l  = log --oneline --decorate -20
lg    = log --graph --oneline --decorate
sw    = switch                          undo = reset --soft HEAD~1
cp    = cherry-pick
```

**This list is provisional and meant to be edited.** It is a defensible starting cut, not a claim about what gets typed.

## Open questions

1. **Is `commit.template` still wanted?** The `gitmessage` prompts for a 50-character subject and an 80-column body answering why/how/side-effects. Useful, but this repository enforces conventional commits through `committed`, and the template predates that. Kept for now because removing it changes daily behaviour; worth a deliberate decision.
2. **Should the `prepare-commit-msg` hook be global or scoped to work repositories?** It is a no-op on any branch without an `ABC-123` pattern, so global is harmless in practice — but a branch named `feat/API-2-thing` would get an unwanted prefix. Scoping it under the same `gitdir:` conditional as the work identity is the tidier answer if that conditional is being written anyway.
3. **`init.defaultBranch = master`.** Both existing configs say `master` and this repository uses it, so it is kept. Noting it only because it is now an unusual choice and the decision should be deliberate rather than inherited.
4. **Does `gh` belong in `git.nix`?** Its only job here is the credential helper, so it sits beside git rather than in a module of its own. It moves out the moment anything else about `gh` is configured.
