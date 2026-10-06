{ lib, config, ... }:
let
  inherit (lib)
    mkOption
    types
    mkDefault
    foldl'
    recursiveUpdate
    ;
in
{
  imports = [
    (import ./storage.nix)
    (import ./http.nix)
    (import ./random.nix)
    (import ./timer.nix)
    (import ./veilid.nix)
  ];

  options = {
    Effects = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
      description = "Available effect constructors and composition combinators";
    };

    mkEffect = mkOption {
      type = types.raw;
      description = "Effect constructor helper that automatically wraps 'on*' callbacks with mkCallback";
    };
  };

  config = {
    # Helper used across all effect submodules
    mkEffect = type: payload: {
      inherit type;
      payload = lib.mapAttrs (
        name: value: if lib.hasPrefix "on" name && value != null then config.mkCallback value else value
      ) payload;
    };

    Effects = {
      Noop = mkDefault {
        type = "Noop";
        payload = { };
      };

      # Run multiple effects concurrently
      Batch = mkDefault (effects: {
        type = "Batch";
        payload = {
          effects = lib.filter (e: e != null && e.type != "Noop") effects;
        };
      });

      # Pure Nix effect chaining:
      # Passes the result of effect A into a function returning effect B,
      # without having to store intermediate results in state.
      andThen = mkDefault (
        fn: effect:
        let
          wrappedOnSuccess =
            result: state:
            let
              # 1. Evaluate the original effect's onSuccess if it had one
              initialOutcome =
                if effect ? payload && effect.payload ? onSuccess && effect.payload.onSuccess != null then
                  effect.payload.onSuccess result state
                else
                  {
                    inherit state;
                    effect = config.Effects.Noop;
                  };

              currentState = initialOutcome.state;

              # 2. Invoke fn with (result) or curried (result: state: ...)
              call = fn result;
              res = if builtins.isFunction call then call currentState else call;

              # 3. Normalize return value: accepts bare Effects, { state, effect }, or state patch
              normalized =
                if builtins.isAttrs res && (res ? effect || res ? state) then
                  {
                    state = res.state or currentState;
                    effect = res.effect or config.Effects.Noop;
                  }
                else if builtins.isAttrs res && res ? type then
                  {
                    state = currentState;
                    effect = res;
                  }
                else if builtins.isAttrs res then
                  {
                    state = recursiveUpdate currentState res;
                    effect = config.Effects.Noop;
                  }
                else
                  {
                    state = currentState;
                    effect = config.Effects.Noop;
                  };
            in
            normalized;
        in
        effect
        // {
          payload = (effect.payload or { }) // {
            onSuccess = config.mkCallback wrappedOnSuccess;
          };
        }
      );

      pipe = mkDefault (
        initialEffect: fns:
        if fns == [ ] then
          initialEffect
        else
          let
            headFn = builtins.head fns;
            tailFns = builtins.tail fns;
          in
          config.Effects.andThen (
            result: state:
            let
              # Execute the current step
              call = headFn result;
              res = if builtins.isFunction call then call state else call;

              # If there are remaining steps and this step produced an effect,
              # recursively pipe the remaining steps onto the new effect!
              resEffect =
                if builtins.isAttrs res && res ? effect then
                  res.effect
                else if builtins.isAttrs res && res ? type then
                  res
                else
                  config.Effects.Noop;

              resPatch =
                if builtins.isAttrs res && (res ? effect || res ? state) then
                  res.state or { }
                else if builtins.isAttrs res && !(res ? type) then
                  res
                else
                  { };
            in
            if tailFns != [ ] && resEffect.type != "Noop" then
              {
                state = resPatch;
                effect = config.Effects.pipe resEffect tailFns;
              }
            else
              res
          ) initialEffect
      );
    };
  };
}
