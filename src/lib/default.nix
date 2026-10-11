{ lib, pkgs, ... }:
{

  mkGestaltIR =
    { modules, wasmModule, ... }:
    let
      ir =
        (lib.evalModules {
          modules = modules ++ [
            ../modules/default.nix
          ];
          specialArgs = {
            inherit wasmModule;
          };
        }).config;
    in
    {
      inherit (ir)
        meta
        initialState
        showcaseState
        veilid
        ;
      view = ir._view;
    };
}
