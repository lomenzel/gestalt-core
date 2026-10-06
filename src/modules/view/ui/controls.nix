# modules/view/ui/controls.nix
{
  lib,
  config,
  target,
  ...
}:
let
  inherit (lib) mkDefault;
  node = (import ../node.nix) { inherit lib target; };
in
{
  config.UI = {
    HTML = mkDefault (
      {
        id ? null,
        html,
        onClick ? null,
        onInput ? null,
        onChange ? null,
        callback ? null,
        ...
      }@args:
      let
        cb = if callback != null then config.mkCallback callback else null;
        clickCb = if onClick != null then config.mkCallback onClick else cb;
        inputCb = if onInput != null then config.mkCallback onInput else cb;
        changeCb = if onChange != null then config.mkCallback onChange else cb;
      in
      node.mkNode "HTML" (
        args
        // {
          inherit id html;
          props = { inherit html; } // (builtins.removeAttrs args [ "id" "callback" "onClick" "onInput" "onChange" ]);
          callback = cb;
          onClick = clickCb;
          onInput = inputCb;
          onChange = changeCb;
        }
      )
    );

    Button = mkDefault (
      {
        id ? null,
        text,
        icon ? null,
        enabled ? true,
        onClick ? null,
        callback ? onClick,
        ...
      }@args:
      let
        wrappedCb = if callback != null then config.mkCallback callback else null;
      in
      if node.supportsNative "Button" then
        node.mkNode "Button" (
          args
          // {
            inherit id text icon enabled;
            props = {
              inherit text icon enabled;
            } // (builtins.removeAttrs args [ "id" "callback" "onClick" ]);
            callback = wrappedCb;
            onClick = wrappedCb;
          }
        )
      else
        config.UI.HTML {
          inherit id;
          html = ''
            <button data-msg="click" ${lib.optionalString (!enabled) "disabled"}>
              ${lib.optionalString (icon != null) ''<span class="icon">${icon}</span> ''}${text}
            </button>
          '';
          onClick =
            msg: state:
            if wrappedCb != null then
              wrappedCb state
            else
              {
                inherit state;
                effect = config.Effects.Noop;
              };
        }
    );

    TextInput = mkDefault (
      {
        id ? null,
        value ? "",
        placeholder ? "",
        type ? "text",
        enabled ? true,
        onInput ? null,
        callback ? onInput,
        ...
      }@args:
      let
        wrappedCb = if callback != null then config.mkCallback callback else null;
      in
      if node.supportsNative "TextInput" then
        node.mkNode "TextInput" (
          args
          // {
            inherit id value placeholder type enabled;
            props = {
              inherit value placeholder type enabled;
            } // (builtins.removeAttrs args [ "id" "callback" "onInput" ]);
            callback = wrappedCb;
            onInput = wrappedCb;
          }
        )
      else
        config.UI.HTML {
          inherit id;
          html = ''
            <input type="${type}"
                   data-on-input="input"
                   value="${value}"
                   ${lib.optionalString (placeholder != "") ''placeholder="${placeholder}"''}
                   ${lib.optionalString (!enabled) "disabled"} />
          '';
          onInput =
            msg: state:
            let
              val = msg.value or "";
            in
            if wrappedCb != null then
              wrappedCb val state
            else
              {
                inherit state;
                effect = config.Effects.Noop;
              };
        }
    );

    Text = mkDefault (
      {
        id ? null,
        text,
        ...
      }@args:
      if node.supportsNative "Text" then
        node.mkNode "Text" (
          args
          // {
            inherit id text;
            props = {
              inherit text;
            } // (builtins.removeAttrs args [ "id" ]);
          }
        )
      else
        config.UI.HTML {
          inherit id;
          html = "<span>${text}</span>";
        }
    );

    Checkbox = mkDefault (
      {
        id ? null,
        label ? "",
        checked ? false,
        enabled ? true,
        onChange ? null,
        callback ? onChange,
        ...
      }@args:
      let
        wrappedCb = if callback != null then config.mkCallback callback else null;
      in
      if node.supportsNative "Checkbox" then
        node.mkNode "Checkbox" (
          args
          // {
            inherit id label checked enabled;
            props = {
              inherit label checked enabled;
            } // (builtins.removeAttrs args [ "id" "callback" "onChange" ]);
            callback = wrappedCb;
            onChange = wrappedCb;
          }
        )
      else
        config.UI.HTML {
          inherit id;
          html = ''
            <label style="display: inline-flex; align-items: center; gap: 8px; cursor: pointer;">
              <input type="checkbox"
                     data-on-change="toggle"
                     ${lib.optionalString checked "checked"}
                     ${lib.optionalString (!enabled) "disabled"} />
              <span>${label}</span>
            </label>
          '';
          onChange =
            msg: state:
            let
              val = msg.value or (!checked);
            in
            if wrappedCb != null then
              wrappedCb val state
            else
              {
                inherit state;
                effect = config.Effects.Noop;
              };
        }
    );
  };
}