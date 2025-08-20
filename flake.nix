{
  description = "Develp Nixos Modules";

  inputs = {
    nixos-2311.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixos-2411.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixos-2505.url = "github:NixOS/nixpkgs/nixos-25.05";

    nixpkgs.follows = "nixos-2505";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    systems.url = "github:nix-systems/default";

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };

    ethereum-nix = {
      url = "github:metacraft-labs/ethereum.nix";
      inputs = {
        nixpkgs.follows = "nixos-2505";
        nixpkgs-2311.follows = "nixos-2311";
        nixpkgs-unstable.follows = "nixpkgs-unstable";
        flake-parts.follows = "flake-parts";
        flake-utils.follows = "flake-utils";
        systems.follows = "systems";
        flake-compat.follows = "flake-compat";
        treefmt-nix.follows = "treefmt-nix";
        fenix.follows = "fenix";
      };
    };

    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs = {
        # https://github.com/yaxitech/ragenix/issues/159
        nixpkgs.follows = "nixos-2411";
        flake-utils.follows = "flake-utils";
      };
    };

    cachix = {
      url = "github:cachix/cachix";
      inputs = {
        flake-compat.follows = "flake-compat";
        nixpkgs.follows = "nixpkgs-unstable";
        git-hooks.follows = "git-hooks-nix";
      };
    };

    nixos-anywhere = {
      url = "github:numtide/nixos-anywhere";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        disko.follows = "disko";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      ...
    }:
    let
      inherit (nixpkgs) lib;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.flake-parts.flakeModules.modules
        ./checks
        ./modules
        ./packages
        ./shells
      ];
      systems = [
        "x86_64-linux" "aarch64-linux"
        "x86_64-darwin" "aarch64-darwin"
      ];
      perSystem =
        { system, ... }:
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        };
      flake.lib.create =
        {
          rootDir,
          machinesDir ? null,
          usersDir ? null,
        }:
        let
          utils = import ./lib { inherit usersDir rootDir machinesDir; };
        in
        {
          dirs = {
            lib = self + "/lib";
            services = self + "/services";
            modules = self + "/modules";
            machines = rootDir + "/machines";
          };
          libs = {
            make-config = import ./lib/make-config.nix {
              inherit
                lib
                rootDir
                machinesDir
                usersDir
                ;
            };
            inherit utils;
          };

          modules = {
            users = import ./modules/users.nix utils;
          };
        };
    };
}
