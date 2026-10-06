# modules/default.nix
{
  lib,
  config,
  ...
}:
{

  imports = [ ./keystore/default.nix ];

  options = {
    meta = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "untitled-application";
      };
      author.name = lib.mkOption {
        type = lib.types.str;
        default = "Anonymous Author";
      };
      version = lib.mkOption {
        type = lib.types.str;
        default = "0";
      };
      title = lib.mkOption {
        type = lib.types.str;
      };
    };

    veilid = {
      autostart = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Start the Veilid node eagerly at app launch instead of waiting for the first interaction.";
      };
    };

    initialState = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "The initial state of the application.";
    };

    showcaseState = lib.mkOption {
      type = lib.types.attrs;
      description = "A showcase state of the application, used for marketing screenshots :)";
    };

    view = lib.mkOption {
      type = lib.types.deferredModule;
      description = "The view module definition.";
    };

    _view = lib.mkOption {
      type = lib.types.raw;
      description = "Evaluates state & target into { componentTree, subscriptions }";
    };
  };

  config = {
    view = { ... }: {
      imports = [ (import ./view) ];
    };

    _view =
      target: state:
      let
        cfg =
          (lib.evalModules {
            modules = [ config.view ];
            specialArgs = {
              inherit target state;
            };
          }).config;

        # 1. State Invariant Error Boundary
        errorBoundaryTree = cfg.UI.HTML {
          html = ''
            <h1>STATE ERROR</h1>
            <p>${state._error.message}</p>
            <button data-msg="prev">Go back to previous state</button>
            <button data-msg="reset">Reset to initial state</button>
          '';
          onClick =
            msg: s:
            if msg == "prev" then
              {
                state = s._error.prevState;
                effect = cfg.Effects.Noop;
              }
            else if msg == "reset" then
              {
                state = config.initialState;
                effect = cfg.Effects.Noop;
              }
            else
              {
                state = s;
                effect = cfg.Effects.Noop;
              };
        };

        # 2. View AST Evaluation
        tree = cfg.componentTree;
        res = builtins.tryEval (lib.deepSeq tree tree);

        evaluatedTree =
          if state ? _error then
            errorBoundaryTree
          else if res.success then
            res.value
          else
            cfg.UI.HTML {
              html = ''
                <h1>VIEW ERROR</h1>
                <p>This is a bug. Contact ${config.meta.author.name}</p>
                <p>If you are ${config.meta.author.name}, and have problems figuring out what happend, dont hesitate to reach ot to me (leonard@menzel.lol)</p>
                <button data-msg="reset">Reset to initial state</button>
              '';
              onClick = msg: s: {
                state = config.initialState;
              };
            };
      in
      {
        componentTree = evaluatedTree;
        # If in error state, pause subscriptions; otherwise supply active subscriptions
        subscriptions = if state ? _error then [ ] else cfg.subscriptions;
        initialEffect = if state ? _error then null else (cfg.initialEffect);
      };

    meta.title = lib.mkDefault config.meta.name;
    showcaseState = lib.mkDefault config.initialState;
  };
}
