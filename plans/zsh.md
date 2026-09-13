# Plan: zsh — the interactive shell, rebuilt natively

Revision 1. Depends on [`foundation.md`](foundation.md); in particular its "Rebuild, do not port" constraint governs everything here.

## Problem

zsh is the first section because everything else is reached through it, and because it is the clearest case of a configuration whose shape was dictated by its previous manager rather than by what it does.

The reference setup (`fernandoaleman/dotfiles`, `dotfiles/dot_config/zsh/`) is 26 files: a `.zshrc`, a `.zshenv`, 14 numbered `conf.d/*.zsh` modules, 5 autoloaded functions and 5 completion files. It works. But its structure exists to solve problems Nix does not have:

- **Platform divergence.** `30-plugins.zsh.tmpl` and `30-fzf.zsh.tmpl` are almost entirely `{{ if .is_mac }} … {{ else if .is_arch }}` blocks selecting between Homebrew and pacman paths.
- **Uncertainty about what is installed.** `10-editor.zsh` guards on `command -v nvim`; `90-path.zsh` guards on `command -v mise`, `command -v starship`, `command -v zoxide`; `50-aliases.zsh.tmpl` guards on `lookPath "bat"` and `lookPath "btm"`.
- **A hand-rolled module loader.** The `.zshrc` exists mostly to build `fpath`, run a cached `compinit`, and `source` the `conf.d` directory in order.

Under Nix, packages are declared and therefore present, paths are identical on both machines, and the loader is the framework's job. Most of this does not get translated — it gets deleted.

Separately, the numbered-prefix convention is actively disliked and is not carried forward in any form.

## Rejected approaches

- **`xdg.configFile."zsh/conf.d/….zsh".source = ./…`.** Preserves the existing files verbatim behind a Nix declaration. This is the ported shape: it would keep the numbering, keep the platform conditionals, and keep the hand-rolled loader, while adding a rebuild step to edit any of it. Explicitly rejected.
- **Inlining everything into `initContent`.** Equally wrong in the other direction. Nix indented strings require `''${` for every `${`, of which the reference zsh config has 17; and a module option that already exists should always beat a string of shell.
- **`programs.zsh.enable = false` with a hand-written zshrc.** Would forfeit `programs.starship.enableZshIntegration`, which writes into `programs.zsh.initContent` and is a silent no-op without it. The same applies to fzf, zoxide and gpg-agent integration.
- **Keeping `conf.d` as a directory of files at all.** Natively this is one module of option assignments. The directory was a loader artifact.

## Chosen design

One `modules/zsh.nix`, composed of home-manager option assignments plus a small amount of `initContent` for the few things zsh has no declarative form for. Every option named below was verified against the home-manager source rather than taken from documentation.

### What each behavior becomes

| Behavior in the reference setup | Native form | Outcome |
|---|---|---|
| `brew shellenv`, `HOMEBREW_NO_ANALYTICS` | Nix supplies the packages; brew's PATH is irrelevant. Casks via `nix-darwin`'s `homebrew` | **Deleted** |
| `VISUAL`/`EDITOR` behind a `command -v nvim` guard | `home.sessionVariables` | **Deleted**, guard included — Nix guarantees nvim exists |
| `CLICOLOR`, `LSCOLORS`, `autoload colors` | BSD-`ls` variables, already dead since `ls` is aliased to eza | **Deleted** |
| `FZF_HOME` per platform; sourcing `completion.zsh` and `key-bindings.zsh` | `programs.fzf` — `enable`, `enableZshIntegration`, `defaultCommand`, `defaultOptions` | **Two files deleted.** home-manager knows where fzf's shell files are in the store |
| zsh-autosuggestions and zsh-syntax-highlighting, four platform paths | `programs.zsh.autosuggestion.enable`, `programs.zsh.syntaxHighlighting.enable` | **Deleted**, load order handled |
| `GPG_TTY=$(tty)` | `services.gpg-agent.enableZshIntegration` | **Deleted** |
| mise / starship / zoxide `eval` blocks, PATH edits | `programs.starship`, `programs.zoxide`, `home.sessionPath` | **Nearly deleted** — only the `.git/safe/../../bin` trusted-repo trick survives as intent |
| History: `HISTFILE`, sizes, 6 `setopt`s | `programs.zsh.history` — `path`, `size`, `save`, `append`, `share`, `ignoreDups`, `ignoreAllDups`, `expireDuplicatesFirst`; plus `historySubstringSearch` with `searchUpKey`/`searchDownKey` | **Pure declaration.** 8 of 9 settings map directly; only `hist_verify` has no option |
| `fpath` construction, cached `compinit`, `conf.d` loader, `typeset +x FPATH` | home-manager generates the zshrc; `programs.zsh.completionInit` carries the 24-hour cache logic verbatim | **`.zshrc` and `.zshenv` both deleted** |
| `bindkey -v` | `programs.zsh.defaultKeymap = "viins"` | Option |
| `setopt autocd …` | `programs.zsh.autocd`; the remainder has no option | Small `initContent` |
| Seven custom `bindkey` lines, `stty -ixon` | Genuinely custom | Small `initContent` |
| ~200 aliases | `programs.zsh.shellAliases`, `programs.zsh.shellGlobalAliases` | Attrset — but see open questions |
| `c()` + `_c` completion for `~/code` | Superseded by zoxide, already an Omarchy default and a home-manager module | Likely **deleted** |
| `completion/` — `_ag _bundler _g _rg _rspec` | Nix packages install their own completions into the profile's `share/zsh/site-functions`; `enableCompletion` discovers them via `fpath` | **Mostly deleted** |
| `encrypted_40-api-tokens.zsh.age` | Out of the repo entirely | See `plans/secrets.md` |

**26 files become one module.** The through-line: the platform conditionals are not translated, they are removed, because the requirement that produced them does not exist once both machines resolve the same store paths.

### Two verified details worth relying on

`programs.zsh.completionInit` is `types.lines` with default `"autoload -U compinit && compinit"`. The existing 24-hour `compinit` cache — including the `(#qN.mh+24)` glob qualifier — moves there intact, so `enableCompletion` stays on rather than being disabled to make room for it.

`programs.zsh.dotDir` defaults to `${config.xdg.configHome}/zsh` when `xdg.enable` is set and `home.stateVersion` is at least `26.05`. The desired XDG layout is the default, not something to fight for.

### Shell functions

The five autoloaded functions are audited individually before anything is written — `mcd` is already known to be unused. Those that survive split by a rule rather than by habit:

- **Mutates shell state** (changes directory, exports, alters the current shell) → stays a zsh function.
- **Everything else** → becomes a `pkgs.writeShellScriptBin` derivation in `home.packages`, which makes it a real program on `PATH`, usable from scripts and from other shells.

## Open questions

1. **Alias trim.** Roughly 200 aliases exist and well under 10% are believed to be in regular use. They are reviewed section by section — unix, bundler, rails, silver-searcher, terraform, git, docker, monitoring — keeping only what is actually typed. The chezmoi alias goes regardless.
2. **Git aliases specifically, ~80 of the total.** `shellAliases` maps the names but not the `compdef _git gst=git-status` companions. The natively-correct alternative is `programs.git.aliases`, which works in every shell and in scripts and brings completion for free — at the cost of changing muscle memory from `gst` to `g st`. Decide during the trim, before any are written.
3. **Does zoxide fully replace `c()`?** `z code` covers the common case. `programs.zsh.dirHashes` is a third option giving `cd ~code`. Expected outcome is that zoxide alone wins and both alternatives are dropped.
4. **`hist_verify`** has no home-manager option and needs one `setopt` line in `initContent` — confirm it is still wanted.
5. **Where do `initContent` ordering boundaries fall?** `programs.starship`'s zsh integration lands at the default order; custom keybindings and `setopt`s likely need `lib.mkOrder` below it. Determine empirically on the first build rather than guessing.
