{ lib, config, ... }:
let
  inherit (lib) mkDefault;
  inherit (config) mkEffect;
in
{
  config.Effects.Random = mkDefault {
    # Cryptographically secure random bytes
    # onSuccess: ({ bytes }, state): ...
    bytes =  (
      {
        length,
        encoding ? "base64", # "base64" | "hex"
        onSuccess ? null,
        onError ? null,
      }:
      mkEffect "Random.Bytes" {
        inherit length encoding onSuccess onError;
      }
    );

    # Native platform UUID (v4)
    # onSuccess: ({ uuid }, state): ...
    uuid =  (
      {
        onSuccess ? null,
        onError ? null,
      }:
      mkEffect "Random.Uuid" {
        inherit onSuccess onError;
      }
    );
  };
}