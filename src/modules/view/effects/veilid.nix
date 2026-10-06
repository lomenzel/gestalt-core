{ lib, config, ... }:
let
  inherit (lib) mkDefault;
  inherit (config) mkEffect;

  # Ensure callbacks are registered with the runtime table (mkCallback) if available
  mkCb = cb: if cb != null then (config.mkCallback or (x: x)) cb else null;
in
{
  config.Effects.Veilid = mkDefault {
    # =======================================================================
    # 1. Routing & Private Routes
    # =======================================================================

    # Allocate an inbound private route on the Veilid network.
    # onSuccess receives: ({ routeId, blob }, state): ...
    newPrivateRoute =
      {
        stability ? "Reliable", # "LowLatency" | "Reliable"
        sequencing ? "EnsureOrdered", # "PreferUnordered" | "EnsureOrdered"
        onSuccess ? null,
        onError ? null,
      }:
      mkEffect "Veilid.NewPrivateRoute" {
        inherit stability sequencing;
        onSuccess = mkCb onSuccess;
        onError = mkCb onError;
      };

    debug =
      {
        command ? "status",
        onSuccess ? null,
        onError ? null,
      }:
      mkEffect "Veilid.Debug" {
        inherit command;
        onSuccess = mkCb onSuccess;
        onError = mkCb onError;
      };

    # Import a peer's serialized route blob so we can address messages to them.
    # onSuccess receives: ({ routeId }, state): ...
    importRemotePrivateRoute =
      {
        blob,
        onSuccess ? null,
        onError ? null,
      }:
      mkEffect "Veilid.ImportRemotePrivateRoute" {
        inherit blob;
        onSuccess = mkCb onSuccess;
        onError = mkCb onError;
      };

    # Free route resources when done or when a peer disconnects
    releasePrivateRoute =
      { routeId }:
      mkEffect "Veilid.ReleasePrivateRoute" {
        inherit routeId;
      };

    # =======================================================================
    # 2. Point-to-Point Messaging (Keyhive-sealed Automerge deltas)
    # =======================================================================

    # One-way push to a peer's route
    # onSuccess receives: ({}, state): ...
    appMessage =
      {
        routeId,
        message, # Base64 string
        onSuccess ? null,
        onError ? null,
      }:
      mkEffect "Veilid.AppMessage" {
        inherit routeId message;
        onSuccess = mkCb onSuccess;
        onError = mkCb onError;
      };

    # Two-way RPC request/response
    # onSuccess receives: ({ response }, state): ...
    appCall =
      {
        routeId,
        request, # Base64 string
        onSuccess ? null,
        onError ? null,
      }:
      mkEffect "Veilid.AppCall" {
        inherit routeId request;
        onSuccess = mkCb onSuccess;
        onError = mkCb onError;
      };

    # Required response when a peer initiates an appCall to us
    # onSuccess receives: ({}, state): ...
    appCallReply =
      {
        callId,
        message, # Base64 string
        onSuccess ? null,
        onError ? null,
      }:
      mkEffect "Veilid.AppCallReply" {
        inherit callId message;
        onSuccess = mkCb onSuccess;
        onError = mkCb onError;
      };

    # =======================================================================
    # 3. Distributed Hash Table (DHT) Operations (Discovery)
    # =======================================================================

    # Allocate a new DHT record
    # onSuccess receives: ({ key, ownerKey }, state): ...
    createDhtRecord =
      {
        schema ? {
          kind = "DFLT";
        },
        subkeys ? 1,
        onSuccess ? null,
        onError ? null,
      }:
      mkEffect "Veilid.CreateDhtRecord" {
        inherit schema subkeys;
        onSuccess = mkCb onSuccess;
        onError = mkCb onError;
      };

    # Write data to a DHT subkey
    # onSuccess receives: ({ result }, state): ...
    setDhtValue =
      {
        key,
        subkey ? 0,
        data, # Base64 string
        onSuccess ? null,
        onError ? null,
      }:
      mkEffect "Veilid.SetDhtValue" {
        inherit key subkey data;
        onSuccess = mkCb onSuccess;
        onError = mkCb onError;
      };

    # Read data from a DHT subkey
    # onSuccess receives: ({ data }, state): ... (data is Base64 string)
    getDhtValue =
      {
        key,
        subkey ? 0,
        forceRefresh ? false,
        onSuccess ? null,
        onError ? null,
      }:
      mkEffect "Veilid.GetDhtValue" {
        inherit key subkey forceRefresh;
        onSuccess = mkCb onSuccess;
        onError = mkCb onError;
      };
  };
}
