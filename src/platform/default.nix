{ pkgs, inputs, ... }:
let
  lib = pkgs.lib;
in
{
  buildApplication =
    {
      modules ? throw "You must provide a list of modules to build an application.",
      target ? pkgs.gestaltPlatform.targets.kirigami,
      extraTargets ? pkgs.gestaltPlatform.targets,
      useUpstreamNix ? (!builtins.hasAttr "reify" builtins) || !builtins.hasAttr "sameFunction" builtins,
      extraInputs ? {},
      extraOverlays ? [],
      src ? null,
      mainFile ? "app.nix",
    }:
    (
      if useUpstreamNix then
        if src == null then
          throw "You must provide a source directory instead of modules when using upstream nix compatibility mode."
        else

          pkgs.callPackage ./upstreamCompat.nix {
            inherit (inputs)
              nixFork
              nixpkgs
              wechselbalg
              self
              ;
            inherit
              inputs
              src
              mainFile
              target
              extraTargets
              pkgs
              extraInputs
              extraOverlays
              ;
            inherit (pkgs.gestaltPlatform) buildApplication;
          }

      else
        let
          modules' = if src != null then [ (import ("${src}/${mainFile}")) ] else modules;
          ir = pkgs.lib.mkGestaltIR {
            modules = modules';
            inherit (pkgs.gestaltPlatform) wasmModule;
          };

          app = target.buildApplication ir;
        in
        (app.overrideAttrs (old: {
          passthru = (old.passthru or { }) // {
            extraTargets =
              old.passthru.extraTargets or { }
              // (lib.mapAttrs (
                name: target:
                target.buildApplication (
                  lib.mkGestaltIR {
                    inherit target;
                    modules = modules';
                    inherit (pkgs.gestaltPlatform) wasmModule;
                  }
                )
              ) extraTargets);
            publish = pkgs.gestaltPlatform.publish modules';
          };
        }))
    );

}
