{
  inputs = {
    nixFork.url = "github:lomenzel/nix";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    wechselbalg.url = "git+file:///home/menzels/gestalt/wechselbalg";
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
      overlays.default = final: prev: {
        lib = prev.lib.extend (
          lfinal: lprev:
          (import ./src/lib {
            lib = lfinal;
            pkgs = final;
          })
          // (wechselbalg.overlays.default final prev).lib

        );

        # flake.nix overlay
        gestaltPlatform = final.lib.recursiveUpdate (prev.gestaltPlatform or { }) (
          import ./src/platform {
            pkgs = final;
            inherit inputs;
          }
          // {
            wasmModule = (
              import ./src/wasmModule.nix {
                pkgs = final;
                lib = final.lib;
              }
            );
          }
        );
      };
      formatter = eachSystem ({ system, ... }: treefmtEval.${system}.config.build.wrapper);

      checks = eachSystem (
        { system, pkgs, ... }: {
          fmt = treefmtEval.${system}.config.build.check self;
        }
      );

    };
}
