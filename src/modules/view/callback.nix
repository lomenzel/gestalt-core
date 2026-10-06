# modules/view/callback.nix
{ lib, config, ... }:
let
  inherit (lib) mkOption types;

  checkInvariants =
    prevState: candidateState:
    let
      failures = lib.filter (inv: !(inv.check candidateState)) config.stateInvariants;
    in
    if failures == [ ] then
      {
        ok = true;
        state = candidateState;
      }
    else
      {
        ok = false;
        error = {
          message = "State invariant violation: " + (lib.concatMapStringsSep ", " (f: f.message) failures);
          failedState = candidateState;
          prevState = prevState;
        };
      };

  normalizeResult =
    prevState: result:
    let
      candidate =
        if builtins.isAttrs result && (result ? state || result ? effect) then
          {
            # Explicit state = ... overrides prevState.
            # If only effect was returned without state, preserve prevState.
            state = if result ? state then result.state else prevState;
            effect = result.effect or config.Effects.Noop;
          }
        else if builtins.isAttrs result then
          # Plain patch ({ myField = val; }): deep-merge into prevState
          {
            state = lib.recursiveUpdate prevState result;
            effect = config.Effects.Noop;
          }
        else
          {
            state = prevState;
            effect = config.Effects.Noop;
          };

      check = checkInvariants prevState candidate.state;
    in
    if check.ok then
      candidate
    else
      {
        state = prevState // {
          _error = check.error;
        };
        effect = config.Effects.Noop;
      };
in
{
  options = {
    stateInvariants = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            message = mkOption {
              type = types.str;
              default = "Invariant failed";
            };
            check = mkOption { type = types.functionTo types.bool; };
          };
        }
      );
      default = [ ];
      description = "List of predicate functions that state must always satisfy";
    };

    mkCallback = mkOption {
      type = types.raw;
      description = "Wraps a callback with return normalization and invariant safety";
    };
  };

  config = {
    mkCallback =
      fn:
      if !(builtins.isFunction fn) then
        fn
      else
        argOrState:
        let
          res = builtins.tryEval (fn argOrState);
        in
        if res.success && builtins.isFunction res.value then
          # Curried form: (val: state: ...)
          candidateState: normalizeResult candidateState (res.value candidateState)
        else if res.success then
          # Single-arg form: (state: ...)
          normalizeResult argOrState res.value
        else
          {
            state = argOrState;
            effect = config.Effects.Noop;
          };
  };
}