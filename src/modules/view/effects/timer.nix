{ lib, config, ... }:
let
  inherit (lib) mkDefault;
  inherit (config) mkEffect;
in
{
  config.Effects.Timer =mkDefault {
    # One-shot delay timer
    delay = (
      {
        ms,
        timerId ? null, # Optional string identifier for cancellation
        onTimeout,      # (state): ...
      }:
      mkEffect "Timer.Delay" {
        inherit ms timerId onTimeout;
      }
    );

    # Cancel a pending delay timer
    cancel =  (
      { timerId }:
      mkEffect "Timer.Cancel" { inherit timerId; }
    );
  };

  config.Effects.Time = {
    # Get current wall-clock & monotonic timestamp
    # onSuccess: ({ timestampMs, isoString }, state): ...
    now =  (
      { onSuccess }:
      mkEffect "Time.Now" { inherit onSuccess; }
    );
  };
}