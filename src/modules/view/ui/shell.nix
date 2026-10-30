# modules/view/ui/shell.nix
{
  lib,
  config,
  target,
  ...
}:
let
  inherit (lib) mkDefault;
  node = import ../node.nix { inherit lib target; };
in
{
  config.UI = {
    NavigationStack = mkDefault (
      {
        id ? null,
        pages ? [ ],
        ...
      }@args:
      node.mkNode "NavigationStack" (args // { inherit id pages; })
    );

    Page = mkDefault (
      {
        id ? null,
        title ? "",
        actions ? [ ],
        children ? [ ],
        onBack ? null,
        ...
      }@args:
      node.mkNode "Page" (
        args
        // {
          inherit id actions children;
          props = {
            inherit title;
            hasBackButton = onBack != null;
          }
          // (builtins.removeAttrs args [
            "id"
            "title"
            "actions"
            "children"
            "onBack"
          ]);
          callback = if onBack != null then config.mkCallback onBack else null;
        }
      )
    );

    Action = mkDefault (
      {
        id ? null,
        text,
        icon ? null,
        shortcut ? null,
        onTrigger ? null,
        enabled ? true,
        visible ? true,
        ...
      }@args:
      node.mkNode "Action" (
        args
        // {
          inherit id;
          props = {
            inherit
              text
              icon
              shortcut
              enabled
              visible
              ;
          }
          // (builtins.removeAttrs args [
            "id"
            "text"
            "icon"
            "shortcut"
            "onTrigger"
            "enabled"
            "visible"
          ]);
          callback = if onTrigger != null then config.mkCallback onTrigger else null;
        }
      )
    );

    Drawer = mkDefault (
      {
        id ? null,
        title ? "",
        actions ? [ ],
        children ? [ ],
        collapsible ? true,
        ...
      }@args:
      node.mkNode "Drawer" (
        args
        // {
          inherit id actions children;
          props = {
            inherit title collapsible;
          }
          // (builtins.removeAttrs args [
            "id"
            "title"
            "actions"
            "children"
            "collapsible"
          ]);
        }
      )
    );
  };
}