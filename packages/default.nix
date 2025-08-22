{ lib, ... }:
{
  perSystem =
    {
      inputs',
      pkgs,
      ...
    }:
    let
      inherit (lib) optionalAttrs versionAtLeast;
      inherit (pkgs) system;
      inherit (pkgs.hostPlatform) isLinux;
    in
    rec {
      legacyPackages = {
        inputs = {
          nixpkgs = rec {
            inherit (pkgs) cachix;
            nix =
              let
                nixStable = pkgs.nixVersions.stable;
              in
              assert versionAtLeast nixStable.version "2.24.10";
              nixStable;
            nix-eval-jobs = pkgs.nix-eval-jobs.override { inherit nix; };
            nix-fast-build = pkgs.nix-fast-build.override { inherit nix-eval-jobs; };
          };
          agenix = inputs'.agenix.packages;
          disko = inputs'.disko.packages;
          ethereum-nix = inputs'.ethereum-nix.packages;
          git-hooks-nix = inputs'.git-hooks-nix.packages;
          nixos-anywhere = inputs'.nixos-anywhere.packages;
          treefmt-nix = inputs'.treefmt-nix.packages;
        };
      };

      packages =
        {
          lido-withdrawals-automation = pkgs.callPackage ./lido-withdrawals-automation { };
        }
        // optionalAttrs (system == "x86_64-linux" || system == "aarch64-darwin") {
          secret = import ./secret { inherit inputs' pkgs; };
        }
        // optionalAttrs isLinux {
          folder-size-metrics = pkgs.callPackage ./folder-size-metrics { };
        };
    };
}
