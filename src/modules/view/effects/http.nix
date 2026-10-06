{ lib, config, ... }:
let
  inherit (lib) mkDefault;
  inherit (config) mkEffect;
in
{
  config.Effects.Http = mkDefault {
    # General-purpose HTTP request
    # onSuccess: ({ status, headers, body }, state): ...
    # onError:   ({ error, status ? null }, state): ...
    request =  (
      {
        url,
        method ? "GET", # "GET" | "POST" | "PUT" | "DELETE" | "PATCH" | "HEAD"
        headers ? { },  # { "Content-Type" = "application/json"; }
        query ? { },    # URL query params { "page" = "1"; }
        body ? null,    # String, JSON attrset, or base64 blob
        timeoutMs ? 30000,
        responseType ? "json", # "json" | "text" | "base64"
        onSuccess,
        onError ? null,
      }:
      mkEffect "Http.Request" {
        inherit url method headers query body timeoutMs responseType onSuccess onError;
      }
    );

    # Shorthand for GET request
    get =  (
      {
        url,
        headers ? { },
        query ? { },
        timeoutMs ? 30000,
        responseType ? "json",
        onSuccess,
        onError ? null,
      }:
      config.Effects.Http.request {
        method = "GET";
        inherit url headers query timeoutMs responseType onSuccess onError;
      }
    );

    # Shorthand for POST JSON request
    postJson =  (
      {
        url,
        body,
        headers ? { },
        timeoutMs ? 30000,
        onSuccess,
        onError ? null,
      }:
      config.Effects.Http.request {
        method = "POST";
        headers = headers // { "Content-Type" = "application/json"; };
        inherit url body timeoutMs onSuccess onError;
        responseType = "json";
      }
    );
  };
}