{
  description = "dotfiles";

  inputs = {
    # Use `github:NixOS/nixpkgs/nixpkgs-26.05-darwin` to use Nixpkgs 26.05.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    # Use `github:nix-darwin/nix-darwin/nix-darwin-26.05` to use Nixpkgs 26.05.
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    
    # nix-os manages all the mac OS level things and to manage the user level things(typically everything inside the user folder)  we use something called homemanager
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Only used for the Pi overlay below. Everything else stays on stable.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nixpkgs-unstable, nix-homebrew, home-manager }:
    let
      # Pi moves faster than the stable channel. nixpkgs-26.05-darwin is frozen
      # at 0.75.4, below the 0.82.0 that settings.json's package pins need to
      # install themselves. Take this one package from unstable; everything else
      # stays pinned to stable.
      piOverlay = final: prev: {
        inherit (nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system})
          pi-coding-agent;
      };
    in
    {
      # This flake describes no machine and no person: it only exports the
      # library. Machines live in a separate private repo that consumes these
      # outputs (scaffold one with `nix flake init -t <this-flake>#machine`).
      # nix-darwin and home-manager are inputs even though no output here
      # builds with them: consumers `follows` them from this flake, so it
      # stays the single point that pins what the library is tested against.

      # The home module tree: shell, editor, CLI, prompt, agents.
      homeManagerModules.default = ./home.nix;

      # macOS system preferences, self-contained: pulls in nix-homebrew's
      # module so a consumer imports exactly one thing.
      darwinModules.default = {
        imports = [
          nix-homebrew.darwinModules.nix-homebrew
          ./modules/system/darwin/defaults.nix
          ./modules/system/darwin/homebrew.nix
          # The restart that makes screencapture.location take effect.
          ./modules/system/darwin/screencapture-restart.nix
        ];
      };

      # Linux system preferences. The base is deliberately small; plain
      # GNOME is a separate importable module because a desktop is a host
      # decision, not a profile one - the home profile has no existence in
      # the NixOS module system.
      nixosModules.default = ./modules/system/nixos/base.nix;
      nixosModules.gnome = ./modules/system/nixos/gnome.nix;

      # The pinned-package overlay, so consumers get the same Pi the library
      # tests against.
      overlays.default = piOverlay;

      # The package list as data. Removing a package on one machine is the
      # dotfiles.excludePackages option; see lib/base-packages.nix.
      lib.basePackages = import ./lib/base-packages.nix;

      templates.machine = {
        path = ./templates/machine;
        description = "A machines repo consuming this library: a flake with the standalone home-manager, darwin and NixOS compositions, example machine files, and the install/update/recovery runbook.";
      };
    };
}
