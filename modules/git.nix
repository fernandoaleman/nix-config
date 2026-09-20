# git, delta and the gh credential helper. See plans/git.md for the audit that
# produced this -- in particular why the aliases are git subcommands rather
# than shell aliases, and which of Omarchy's own git settings are carried
# forward here rather than lost when home-manager takes over the file.
{ pkgs, ... }:

let
  # Rebuilt from the reference setup's git_template hook. That hook was always
  # generic -- it lifts any ABC-123 from the branch name -- so only its example
  # comment was work-specific.
  #
  # Delivered through init.templatedir, not programs.git.hooks. The latter sets
  # core.hooksPath, which overrides .git/hooks for *every* repository and would
  # silently disable the prek hooks this repo installs via `make setup`.
  # templatedir keeps the original semantics: copied in at clone or init time,
  # per repository, leaving existing hooks alone.
  gitTemplate = pkgs.runCommand "git-template" { } ''
    mkdir -p "$out/hooks"
    cp ${./git/prepare-commit-msg} "$out/hooks/prepare-commit-msg"
    chmod +x "$out/hooks/prepare-commit-msg"
  '';
in
{
  programs.git = {
    enable = true;

    ignores = [
      # Editor and OS noise
      "*.sw[nop]"
      ".DS_Store"
      # Secrets -- belt and braces; these should never be in a repo anyway
      ".env"
      ".env.*"
      # Ruby / Rails
      ".bundle/"
      "/vendor/bundle/"
      ".byebug_history"
      "pry_history"
      "coverage/"
      "db/*.sqlite3"
      "log/*"
      "tmp/**/*"
      "!.keep"
      # Node
      "node_modules/"
      "npm-debug.log*"
      "yarn-debug.log*"
      # Built assets
      "public/assets/"
      "public/packs-*"
      # Agents
      "**/.claude/settings.local.json"
    ];

    # `settings`, not `extraConfig`: the latter is a deprecation shim on the
    # home-manager revision pinned in flake.lock. Same for `settings.alias`,
    # `settings.user.name` and `settings.user.email`.
    settings = {
      user = {
        name = "Fernando Aleman";
        # Personal address, already public in this repository's own history.
        # The work identity is a gitdir: conditional include that lives outside
        # the repo -- see plans/secrets.md.
        email = "fernandoaleman@mac.com";
      };

      # Mostly names already present in *both* Omarchy's git config and the
      # reference setup's, plus a few promoted from the shell aliases. The
      # rest of the 79 dissolved or were dropped; plans/git.md has the list.
      #
      # `co` is deliberately absent, though both existing configs ship it.
      # `git checkout` is two commands wearing one name: `checkout <branch>`
      # switches, `checkout <file>` destroys uncommitted work with no
      # confirmation and no undo. `switch` cannot touch the working tree, so
      # removing the shortcut means the dangerous spelling is never the one
      # that comes out of muscle memory. `git checkout` still works when typed
      # in full.
      alias = {
        aa = "add --all";
        amend = "commit -v --amend";
        ap = "add --patch";
        br = "branch";
        ci = "commit -v";
        cp = "cherry-pick";
        d = "diff";
        dc = "diff --cached";
        l = "log --oneline --decorate -20";
        lg = "log --graph --oneline --decorate";
        pf = "push --force-with-lease";
        st = "status";
        sw = "switch";
        undo = "reset --soft HEAD~1";
        # `git stash save --include-untracked --no-keep-index` from the
        # reference setup, modernised: git's own docs say save "is deprecated
        # in favour of git stash push", and --no-keep-index is already push's
        # default -- it exists only to counteract --patch, which implies
        # --keep-index. So two of the three flags were doing nothing.
        wip = "stash push --include-untracked";
      };

      # Carried forward from Omarchy's config. home-manager replaces that file
      # rather than merging into it, so these would be lost silently.
      branch.sort = "-committerdate";
      column.ui = "auto";
      commit.verbose = true;
      pull.rebase = true;
      push.autoSetupRemote = true;
      rerere = {
        autoupdate = true;
        enabled = true;
      };
      tag.sort = "-version:refname";

      # Both configs say master, and this repository uses it.
      init = {
        defaultBranch = "master";
        templatedir = "${gitTemplate}";
      };


      diff = {
        algorithm = "histogram";
        # A deliberate disagreement with Omarchy, which sets `plain`. `zebra`
        # alternates shades so a block that moved *and changed* is visibly
        # different from one that moved verbatim. Noisier, and worth it.
        colorMoved = "zebra";
        mnemonicPrefix = true;
      };
      fetch.prune = true;
      merge.conflictstyle = "zdiff3";
      rebase.autosquash = true;
    };
  };

  # enableGitIntegration is what sets core.pager and interactive.diffFilter, so
  # the two lines that existed purely to wire delta into git are deleted rather
  # than translated. It defaults to *false* -- without it delta is installed and
  # styled but git never calls it, which looks like the config silently not
  # working.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      features = "side-by-side line-numbers decorations";
      hyperlinks = true;
      navigate = true;
      side-by-side = true;
      decorations = {
        commit-decoration-style = "bold yellow box ul";
        file-style = "bold yellow ul";
        file-decoration-style = "none";
        hunk-header-decoration-style = "cyan box ul";
      };
      line-numbers = {
        line-numbers-left-style = "cyan";
        line-numbers-right-style = "cyan";
        line-numbers-minus-style = "124";
        line-numbers-plus-style = "28";
      };
    };
  };

  # Here only for gitCredentialHelper, which defaults to true and covers both
  # github.com and gist.github.com. It replaces the entries `gh auth login`
  # wrote by hand, which hardcode a mise install path pinned to gh 2.100.0 and
  # break on the next `mise up`. Moves to its own module if anything else about
  # gh is ever configured.
  programs.gh = {
    enable = true;
    # Declaring programs.gh also hands home-manager gh's config.yml, whose
    # default here would be `aliases: {}` -- silently dropping the `co` alias
    # gh itself ships with. Carried forward explicitly. The auth token lives in
    # hosts.yml, which is not managed and must not be.
    settings.aliases.co = "pr checkout";
  };
}
