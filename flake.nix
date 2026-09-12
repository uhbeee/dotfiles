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
      # The one username line to change if this isn't your machine.
      # bootstrap.sh offers to rewrite this for you if your macOS username differs.
      user = "adasari";

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
      darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit user; };
        modules = [
          ./configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            nixpkgs.overlays = [ piOverlay ];
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit user; };
            # Identity is this machine's, so it lives here with the machine,
            # not in the exported home.nix.
            home-manager.users.${user} = {
              imports = [ ./home.nix ];
              home.username = user;
              home.homeDirectory = "/Users/${user}";
              home.stateVersion = "24.11";
              # This machine develops the library: authored configs link into
              # the checkout and are editable in place. Consumers leave this
              # unset and get everything read-only from the store.
              dotfiles.devCheckout = "/Users/${user}/.dotfiles";
            };
          }
        ];
      };

      # Consumer-facing outputs. Additive: the Mac above still builds from its
      # own wiring; these make the same modules importable by a machines repo
      # (scaffold one with `nix flake init -t <this-flake>#machine`).

      # The home module tree: shell, editor, CLI, prompt, agents.
      homeManagerModules.default = ./home.nix;

      # macOS system preferences, self-contained: pulls in nix-homebrew's
      # module so a consumer imports exactly one thing.
      darwinModules.default = {
        imports = [
          nix-homebrew.darwinModules.nix-homebrew
          ./modules/system/darwin/defaults.nix
          ./modules/system/darwin/homebrew.nix
          # The restart that makes screencapture.location take effect; see the
          # note in that file for why configuration.nix has its own copy.
          ./modules/system/darwin/screencapture-restart.nix
        ];
      };

      # The pinned-package overlay, so consumers get the same Pi the library
      # tests against.
      overlays.default = piOverlay;

      # The package list as data. Removing a package on one machine is the
      # dotfiles.excludePackages option; see lib/base-packages.nix.
      lib.basePackages = import ./lib/base-packages.nix;

      templates.machine = {
        path = ./templates/machine;
        description = "A machines repo consuming this library: a flake with the standalone home-manager and darwin compositions, an example machine file, and the install/update/recovery runbook.";
      };
    };
}
