# ArtCraft Launcher — NixOS flake
#
# Installs ArtCraft Launcher (https://github.com/storytold/craft-launcher)
# from the official prebuilt .tar.gz releases.
#
# Layout:
#   sources.nix                      release metadata: version, URLs, hashes
#   packages/artcraft-launcher.nix   the package derivation
#   modules/artcraft-launcher.nix    NixOS module (programs.artcraft-launcher)
#   overlays/default.nix             overlay exposing pkgs.artcraft-launcher
#   README.md                        usage docs
{
  description = "ArtCraft Launcher - install, update and launch the Craft App Suite";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      sources = import ./sources.nix;

      # One supported system per release asset (see sources.nix).
      forAllSystems = lib.genAttrs (builtins.attrNames sources.perSystem);
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          artcraft-launcher = pkgs.callPackage ./packages/artcraft-launcher.nix {
            inherit sources system;
          };
          default = self.packages.${system}.artcraft-launcher;
        }
      );

      overlays = {
        artcraft-launcher = import ./overlays/default.nix { inherit self; };
        default = self.overlays.artcraft-launcher;
      };

      nixosModules = {
        # Wrap the module file so it can also see the flake's own `self`,
        # without the file itself being flake-aware.
        artcraft-launcher =
          { lib, config, pkgs, ... }:
          import ./modules/artcraft-launcher.nix {
            inherit lib config pkgs self;
          };
        default = self.nixosModules.artcraft-launcher;
      };
    };
}
