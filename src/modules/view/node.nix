# modules/view/node.nix
{ lib, target, ... }:
{
  mkNode =
    type:
    {
      id ? null,
      props ? { },
      ...
    }@args:
    {
      inherit type;
      id = if id != null then id else args.key or null;
      props = builtins.removeAttrs args [
        "id"
        "key"
        "children"
        "pages"
        "actions"
        "callback"
        "onClick"
        "onInput"
        "onChange"
      ];
    }
    // (lib.optionalAttrs (args ? pages) { inherit (args) pages; })
    // (lib.optionalAttrs (args ? children) { inherit (args) children; })
    // (lib.optionalAttrs (args ? actions) { inherit (args) actions; })
    // (lib.optionalAttrs (args ? callback) { inherit (args) callback; })
    // (lib.optionalAttrs (args ? onClick) { inherit (args) onClick; })
    // (lib.optionalAttrs (args ? onInput) { inherit (args) onInput; })
    // (lib.optionalAttrs (args ? onChange) { inherit (args) onChange; });

  supportsNative =
    comp:
    let
      targetComponents =
        if builtins.isAttrs target && target ? uiComponents then
          target.uiComponents
        else if target == "web" then
          [
            "Button"
            "TextInput"
            "Text"
            "Checkbox"
            "ColumnLayout"
            "RowLayout"
          ]
        else
          [ ];
      normTargetList = map lib.toLower targetComponents;
    in
    builtins.elem (lib.toLower comp) normTargetList;
}