# src/wasm-wrap.nix  (no pkgs, no lib)
{ wasm, name, argNames, bytecode }:
callArgs:
if builtins.attrNames callArgs != argNames then
  throw "${name}: expected args [${toString argNames}]"
else
  let
    res = wasm { inherit bytecode; function = "call"; } callArgs;
  in
  if res.success then res.data else throw "wasmModule [${name}]: ${res.error}"