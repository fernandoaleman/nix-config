# Beelink SER8 -- Omarchy (Arch). Omarchy owns the system layer; everything
# here is the user environment only.
{
  # Shared modules -- everything portable to the Mac lives in ../../modules.
  imports = [
    ../../modules/bash.nix
    ../../modules/git.nix
  ];

  home.username = "faleman";
  home.homeDirectory = "/home/faleman";

  # Set once, at first install, and then left alone: this declares which
  # release's default *behaviours* the configuration was written against, not
  # which nixpkgs is tracked. Bumping it later silently changes defaults
  # underneath a working config.
  #
  # 26.05 specifically, because programs.zsh.dotDir defaults to
  # ${config.xdg.configHome}/zsh only when xdg.enable is true *and*
  # stateVersion is at least 26.05. Verified in home-manager's
  # modules/programs/zsh/default.nix on both master and release-26.05.
  home.stateVersion = "26.05";

  xdg.enable = true;

  # Puts the home-manager CLI in the profile, so every switch after the first
  # one is `home-manager switch` rather than a nix build plus an activate.
  programs.home-manager.enable = true;
}
