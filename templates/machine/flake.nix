{
  description = "machines";

  inputs = {
    # Point this at the library: your GitHub fork/user, or
    # git+ssh://git@github.com/<you>/dotfiles.git for a private repo.
    dotfiles.url = "github:CHANGE-ME/dotfiles";
    # Pinned to what the library tests against, not the implicit registry.
    nixpkgs.follows = "dotfiles/nixpkgs";
    home-manager.follows = "dotfiles/home-manager";
    # Only the darwin composition below needs this one.
    nix-darwin.follows = "dotfiles/nix-darwin";
    # Declarative disk layout for NixOS machines; nixos-anywhere applies it
    # at install time. A machine concern, so it is this repo's input, never
    # the library's.
    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, dotfiles, nixpkgs, home-manager, nix-darwin, disko, ... }:
    let
      # One file per machine; see machines/README notes in README.md.
      machine = import ./machines/example.nix;

      pkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [ dotfiles.overlays.default ];  # pinned packages, e.g. Pi
        config.allowUnfree = true;                 # your call, not the library's
      };
    in
    {
      # Composition one: standalone home-manager. For any machine where you
      # own the home directory but not the OS. Apply with:
      #   nix run home-manager -- switch --flake .#"<user>@<host>"
      homeConfigurations."${machine.user}@${machine.host}" =
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor machine.system;
          modules = [
            dotfiles.homeManagerModules.default
            {
              home.username = machine.user;
              home.homeDirectory = machine.homeDirectory;
              home.stateVersion = machine.stateVersion;
              dotfiles.profile = machine.profile;
              # Activating a built activationPackage does not install the
              # home-manager CLI by itself. This does, from this flake's
              # locked input, so `home-manager generations` and rollbacks
              # work without a registry lookup.
              programs.home-manager.enable = true;
            }
          ];
        };

      # Composition two: nix-darwin owning the whole Mac with home-manager
      # inside it. Apply with:
      #   sudo darwin-rebuild switch --flake .#<host>
      darwinConfigurations.${machine.host} = nix-darwin.lib.darwinSystem {
        modules = [
          dotfiles.darwinModules.default
          home-manager.darwinModules.home-manager
          {
            # The runbook installs Determinate Nix, which manages the daemon
            # itself, so nix-darwin must not. If you chose a different
            # installer that expects nix-darwin to own the daemon, drop this.
            nix.enable = false;

            nixpkgs.hostPlatform = machine.system;
            nixpkgs.overlays = [ dotfiles.overlays.default ];
            nixpkgs.config.allowUnfree = true;

            system.primaryUser = machine.user;
            users.users.${machine.user}.home = machine.homeDirectory;
            # nix-darwin's own baseline on this machine. Like home-manager's
            # stateVersion: set once at install, never bumped.
            system.stateVersion = 6;

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${machine.user} = {
              imports = [ dotfiles.homeManagerModules.default ];
              home.stateVersion = machine.stateVersion;
              dotfiles.profile = machine.profile;
            };
          }
        ];
      };

      # Composition three: NixOS owning a whole machine, with home-manager
      # inside it. The host is a directory module (machines/example-nixos/),
      # not a question-file: a NixOS host also answers hardware and disk
      # questions, which no attrset covers. Scaffold a real machine by
      # copying the directory and renaming this output. Apply on the machine:
      #   sudo nixos-rebuild switch --flake .#example-nixos
      nixosConfigurations.example-nixos = nixpkgs.lib.nixosSystem {
        # Lets the host module import the library's home module for its user.
        specialArgs = { inherit dotfiles; };
        modules = [
          dotfiles.nixosModules.default
          # A desktop is a host decision: drop this line for a server.
          dotfiles.nixosModules.gnome
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          ./machines/example-nixos
          {
            nixpkgs.overlays = [ dotfiles.overlays.default ];
            nixpkgs.config.allowUnfree = true;
          }
        ];
      };
    };
}
