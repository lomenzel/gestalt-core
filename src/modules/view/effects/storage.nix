{ lib, config, ... }:
let
  inherit (lib) mkDefault;
  inherit (config) mkEffect;
in
{
  config.Effects.Storage = mkDefault {
    # Retrieve a value by key
    # onSuccess: ({ value }, state): ... 
    # onError: ({ error }, state): ...

    # if key does not exist, onError will be called
    get = (
      {
        key,
        namespace ? "default",
        onSuccess ? null,
        onError ? null,
      }:
      mkEffect "Storage.Get" {
        inherit
          key
          namespace
          onSuccess
          onError
          ;
      }
    );

    # Store a JSON/text value
    set = (
      {
        key,
        value, # String, boolean, number, or JSON-serializable attrset/list
        namespace ? "default",
        onSuccess ? null, # (state): ...
        onError ? null, # ({ error }, state): ...
      }:
      mkEffect "Storage.Set" {
        inherit
          key
          value
          namespace
          onSuccess
          onError
          ;
      }
    );

    # Remove a key from storage
    delete = (
      {
        key,
        namespace ? "default",
        onSuccess ? null,
        onError ? null,
      }:
      mkEffect "Storage.Delete" {
        inherit
          key
          namespace
          onSuccess
          onError
          ;
      }
    );

    # Clear an entire namespace/bucket
    clear = (
      {
        namespace ? "default",
        onSuccess ? null,
        onError ? null,
      }:
      mkEffect "Storage.Clear" {
        inherit namespace onSuccess onError;
      }
    );

    # List all keys in a namespace with optional prefix
    # onSuccess: ({ keys }, state): ...
    listKeys = (
      {
        namespace ? "default",
        prefix ? "",
        onSuccess ? null,
        onError ? null,
      }:
      mkEffect "Storage.ListKeys" {
        inherit
          namespace
          prefix
          onSuccess
          onError
          ;
      }
    );
  };
}
