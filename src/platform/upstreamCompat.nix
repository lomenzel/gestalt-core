{
  src,
  mainFile,
  target,
  extraTargets ? { },
  extraInputs ? { }, # <-- New: { keyhive-nix = keyhive-nix; automerge-nix = automerge-nix; ... }
  extraOverlays ? [ ], # <-- New: [ "keyhive-nix.overlays.default" "automerge-nix.overlays.default" ]
  nixFork,
  nixpkgs,
  pkgs,
  wechselbalg,
  inputs,
  self,
  buildApplication,
  ...
}:
let
  ir = pkgs.lib.mkGestaltIR {
    modules = [ "${src}/${mainFile}" ];
    inherit (pkgs.gestaltPlatform) wasmModule;
  };
  inherit (pkgs) lib;

  collectInputs =
    prefix: inputs:
    collectInputs' prefix inputs { }
    |> map ({ name, path }: " --override-input ${name} path:${path} ")
    |> lib.concatStringsSep "";

  collectInputs' =
    prefix: inputs: visitedPaths:
    lib.attrsToList (lib.removeAttrs inputs [ "self" ])
    |> map (
      { name, value }:
      let
        path = if builtins.hasAttr "outPath" value then toString value.outPath else toString value;
      in
      if (builtins.hasAttr (builtins.unsafeDiscardStringContext path) visitedPaths) then
        [ ]
      else
        [
          {
            name = "${prefix}/${name}";
            inherit path;
          }
        ]
        ++ (lib.optional (builtins.hasAttr "inputs" value) (
          collectInputs' "${prefix}/${name}" value.inputs (
            visitedPaths // { ${builtins.unsafeDiscardStringContext path} = true; }
          )
        ))
    )
    |> lib.flatten;

  # Format inputs for generated flake.nix
  extraInputsLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: input: "        ${name}.url = \"path:${input.outPath}\";") extraInputs
  );

  extraInputsArgList = lib.concatStringsSep ", " (lib.attrNames extraInputs);

  extraOverlaysLines = lib.concatStringsSep "\n              " extraOverlays;

  extraInputsOverrides = lib.concatStringsSep " " (
    lib.mapAttrsToList (name: input: collectInputs name (input.inputs or { })) extraInputs
  );

  flake = pkgs.writeText "flake.nix" ''
        {
          inputs = {
            nixpkgs.url = "path:${nixpkgs.outPath}";
            core.url = "path:${self.outPath}";
            target.url = "path:${target.input.outPath}";
    ${extraInputsLines}
          };
          outputs = { self, nixpkgs, core, target, ${extraInputsArgList}${
            lib.optionalString (extraInputsArgList != "") ","
          } ... }:
            let
              pkgs = import nixpkgs {
                system = "${pkgs.stdenv.buildPlatform.system}";
                overlays = [
                  ${extraOverlaysLines}
                  core.overlays.default
                  target.overlays.default

                ];
              };
            in
            {
              packages.${pkgs.stdenv.buildPlatform.system}.default = pkgs.gestaltPlatform.buildApplication {
                src =  /. + "${src}";
                mainFile = "${mainFile}";
                target = pkgs.gestaltPlatform.targets.${target.name};
              };
            };
        }
  '';
in
pkgs.stdenv.mkDerivation {
  pname = ir.meta.name;
  version = "${ir.meta.version}-upstreamCompat-${target.name}";
  dontUnpack = true;
  installPhase = ''
    export HOME=$(mktemp -d)
    mkdir sub
    cp ${flake} sub/flake.nix
    cd sub

    echo "==================== [DEBUG] GENERATED sub/flake.nix ===================="
    cat flake.nix
    echo "=========================================================================="

    NIX_BIN="${nixFork.packages.${pkgs.stdenv.buildPlatform.system}.default}/bin/nix"
    COMMON_FLAGS="--impure --offline --extra-experimental-features 'flakes nix-command pipe-operators ast-introspection' --option flake-registry \"\" ${collectInputs "core" inputs} ${collectInputs "target" target.input.inputs} ${extraInputsOverrides}"

    echo "=== [TEST 1] Testing if pkgs.lib has keyhive inside sub/flake.nix ==="
    eval "$NIX_BIN eval .#packages.${pkgs.stdenv.buildPlatform.system}.default.overrideAttrs --apply 'x: false' $COMMON_FLAGS" 2>/dev/null || true
    eval "$NIX_BIN eval --expr '(let f = builtins.getFlake (toString ./.); p = f.outputs.packages.${pkgs.stdenv.buildPlatform.system}.default; in { hasKeyhive = (import f.inputs.nixpkgs { system = \"${pkgs.stdenv.buildPlatform.system}\"; overlays = [ f.inputs.keyhive-nix.overlays.default ]; }).lib ? keyhive; })' $COMMON_FLAGS" || true

    echo "=== [TEST 2] Running full build ==="
    eval "$NIX_BIN build -L .#default $COMMON_FLAGS"

    ls -lah
    cp -r ./result $out
  '';
  passthru =
    let
      buildPassthru =
        attrName:
        pkgs.stdenv.mkDerivation {
          name = "${ir.meta.name}-${if attrName == "devServer" then "dev" else attrName + "-upstreamCompat"}";
          version = ir.meta.version;
          dontUnpack = true;
          installPhase = ''
            export HOME=$(mktemp -d)
            mkdir sub
            cp ${flake} sub/flake.nix
            cd sub
            ${
              nixFork.packages.${pkgs.stdenv.buildPlatform.system}.default
            }/bin/nix build -L $pwd\#default.${attrName} --impure --offline --extra-experimental-features 'flakes nix-command pipe-operators' --option flake-registry "" \
              ${collectInputs "core" inputs} ${collectInputs "target" target.input.inputs} ${extraInputsOverrides}
            ls -lah
            cp -r ./result $out
          '';
          dontFixup = true;
          requiredSystemFeatures = [ "recursive-nix" ];
        };
    in
    {
      extraTargets = builtins.mapAttrs (
        _: t:
        buildApplication {
          inherit
            src
            mainFile
            extraInputs
            extraOverlays
            ;
          target = t;

        }
      ) extraTargets;
      devServer = buildPassthru "devServer";
      publish = buildPassthru "publish";
      appJS = buildPassthru "appJS";
      screenshot = buildPassthru "screenshot";
    };
  dontFixup = true;
  requiredSystemFeatures = [ "recursive-nix" ];
}
