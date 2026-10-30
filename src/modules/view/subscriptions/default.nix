{ lib, config, ... }:
let
  inherit (lib) mkOption types;
in
{
  imports = [
    (import ./veilid.nix)
  ];

  options = {
    subscriptions = mkOption {
      type = types.listOf types.raw;
      default = [ ];
      description = "Active network and event subscriptions for this render cycle";
    };

    Sub = mkOption {
      type = types.attrsOf (types.attrsOf types.raw);
      default = { };
      description = "Subscription constructors grouped by provider";
    };
  };
}