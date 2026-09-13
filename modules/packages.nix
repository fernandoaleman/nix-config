# CLI tools, pinned by flake.lock. See plans/packages.md for the rule that
# decides what belongs here.
#
# Binaries only. No configuration, no shell integration. Omarchy's rc already
# aliases ls to eza, exports BAT_THEME, and runs starship/mise/zoxide/fzf init;
# adding programs.* modules for these would fight the layer modules/bash.nix
# deliberately preserves. Because ~/.nix-profile/bin precedes /usr/bin,
# Omarchy's own init transparently picks up the binaries declared here.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # ── Reading and searching ────────────────────────────
    bat
    eza
    fd
    ripgrep
    jq
    # fzf is declared in modules/fzf.nix, which owns its shell integration and
    # installs the package itself.

    # ── System ───────────────────────────────────────────
    btop
    ncdu

    # ── Git ──────────────────────────────────────────────
    # git, delta and gh come from modules/git.nix, which configures them.
    lazygit

    # ── Network and transfer ─────────────────────────────
    nmap
    rclone
    rsync
    wget

    # ── Secrets ──────────────────────────────────────────
    # Needed by plans/secrets.md before any private material lands.
    age
    gnupg

    # ── Authoring ────────────────────────────────────────
    # shellcheck runs against this repository's own scripts.
    shellcheck
    tldr

    # ── Prompt and navigation ────────────────────────────
    # Installed but not configured: Omarchy's rc initialises all three, and
    # resolves them through PATH, so these are the binaries it initialises.
    starship
    zoxide
  ];
}
