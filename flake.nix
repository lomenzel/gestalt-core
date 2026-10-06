{
  inputs = {
    nixFork.url = "github:lomenzel/nix";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    wechselbalg.url = "git+file:///home/leonard/Projekte/Gestalt/wechselbalg";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      wechselbalg,
      ...
    }@inputs:
    let
      eachSystem =
        f:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              overlays = [
                wechselbalg.overlays.default
                self.overlays.default
              ];
            };
          }
        );
      treefmtEval = eachSystem ({ pkgs, ... }: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
    in
    {
      overlays.default =
        final: prev:

        {
          lib =
            prev.lib
            // import ./src/lib {
              inherit (final) lib;
            }
            // (wechselbalg.overlays.default final prev).lib;
        }
        // {
          gestaltPlatform = final.lib.recursiveUpdate (prev.gestaltPlatform or {}) (
            import ./src/platform {
              pkgs = final;
              inherit inputs;
            }
          );
        };

      formatter = eachSystem ({ system, ... }: treefmtEval.${system}.config.build.wrapper);

      checks = eachSystem (
        { system, pkgs, ... }:

        self.packages.${system}
        // {
          fmt = treefmtEval.${system}.config.build.check self;
        }
      );

    };
}
