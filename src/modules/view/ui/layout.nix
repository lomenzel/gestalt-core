# modules/view/ui/layout.nix
{
  lib,
  target,
  ...
}:
let
  inherit (lib) mkDefault;
  node = import ../node.nix { inherit lib target; };
in
{
  config.UI = {
    ColumnLayout = mkDefault (
      {
        id ? null,
        children ? [ ],
        spacing ? 8,
        ...
      }@args:
      node.mkNode "ColumnLayout" (
        args
        // {
          inherit id children;
          props = {
            inherit spacing;
          }
          // (builtins.removeAttrs args [
            "id"
            "children"
            "spacing"
          ]);
        }
      )
    );

    RowLayout = mkDefault (
      {
        id ? null,
        children ? [ ],
        spacing ? 8,
        ...
      }@args:
      node.mkNode "RowLayout" (
        args
        // {
          inherit id children;
          props = {
            inherit spacing;
          }
          // (builtins.removeAttrs args [
            "id"
            "children"
            "spacing"
          ]);
        }
      )
    );
  };
}