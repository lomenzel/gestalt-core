# modules/view/ui/default.nix
{ lib, ... }:
{
  imports = [
    (import ./shell.nix)
    (import ./layout.nix)
    (import ./controls.nix)
  ];

  options = {
    UI = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = { };
      description = "Available UI constructors";
    };
  };
}