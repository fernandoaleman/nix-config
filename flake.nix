{
  description = "Nix + home-manager configuration for Omarchy and macOS";

  inputs = {
    # Unstable rather than a release branch: Omarchy is rolling, so pinning
    # half the machine to a six-month-old snapshot would drift against the
    # pacman half. flake.lock pins this just as hard as a release branch
    # would -- "unstable" names the channel, not the reproducibility.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # tobi/try, not nixpkgs' unrelated `try`. See modules/try.nix.
    try = {
      url = "github:tobi/try";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      # Without this, home-manager evaluates against its own nixpkgs and the
      # machine ends up with two of them.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ home-manager, nixpkgs, ... }:
    {
      # Named "<user>@<host>", which is the form home-manager's own CLI looks
      # for when it is given a bare `--flake .`. The Makefile passes the
      # attribute explicitly anyway, so a switch never depends on what the
      # machine currently calls itself.
      homeConfigurations."faleman@beelink" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages."x86_64-linux";
        modules = [ ./hosts/beelink ];
        # Flake inputs reach modules through this; modules/try.nix needs the
        # upstream home-manager module out of the try input.
        extraSpecialArgs = { inherit inputs; };
      };

      # Standalone home-manager, not nix-darwin -- see hosts/macbook-pro.
      homeConfigurations."faleman@macbook-pro" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages."aarch64-darwin";
        modules = [ ./hosts/macbook-pro ];
        extraSpecialArgs = { inherit inputs; };
      };

      # The same macOS host under a throwaway account, for testing a switch
      # without touching a working machine. hosts/macbook-pro pins the username
      # and home directory, so they are forced aside here rather than the host
      # being made generic for one temporary consumer.
      #
      # Delete this output once the real account has migrated.
      homeConfigurations."nixtest@macbook-pro" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages."aarch64-darwin";
        modules = [
          ./hosts/macbook-pro
          {
            home.username = nixpkgs.lib.mkForce "nixtest";
            home.homeDirectory = nixpkgs.lib.mkForce "/Users/nixtest";
          }
        ];
        extraSpecialArgs = { inherit inputs; };
      };
    };
}
