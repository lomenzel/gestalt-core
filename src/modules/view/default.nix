# modules/view/default.nix
{
  lib,
  config,
  ...
}:
let
  inherit (lib) mkOption types mkDefault;
in
{
  imports = [
    (import ./callback.nix)
    (import ./effects)
    (import ./subscriptions)
    (import ./ui)
  ];

  options = {
    componentTree = mkOption {
      type = types.raw;
      description = "The evaluated root component tree to be displayed.";
    };
    initialEffect = lib.mkOption {
      type = lib.types.raw;
      default = null;
      description = "An effect to be executed once by the runtime on initial app boot.";
    };
  };

  config = {
    componentTree = mkDefault (
      config.UI.HTML {
        callback = state: {
          inherit state;
          effect = config.Effects.Noop;
        };
        html = "<p>forgot to set componentTree? RTFM</p>";
      }
    );
  };
}
