# `cfg` is closed over from default.nix (the app-level options).
cfg:
{ lib, config, state, ... }:
let
  inherit (lib) mkOption types;
  UI = config.UI;
  E = config.Effects;
  crypto = cfg._crypto;

  nsEncrypted = "_gestaltInternal:keystore:encrypted";
  nsPlain = "_gestaltInternal:keystore:plain";
  vaultKey = "vault";

  ks = state._gestaltInternal.keystore; # this module's own slice
  noDraft = { pass = ""; pass2 = ""; old = ""; };

  # ── state plumbing ───────────────────────────────────────────────────
  slice = s: s._gestaltInternal.keystore;
  put = s: k: s // { _gestaltInternal = s._gestaltInternal // { keystore = k; }; };
  upd = f: s: put s (f (slice s));
  done = st: { state = st; effect = E.Noop; };
  step = st: effect: { state = st; inherit effect; };

  setDraft = field: val: s:
    done (upd (k: k // { draft = k.draft // { ${field} = val; }; }) s);
  fail = msg: s: done (upd (k: k // { error = msg; }) s);
  storeFailed = { error }: s: fail "Could not write keystore: ${error}" s;

  # Callbacks only receive state when they fire, so anything that needs the
  # *current* state plus fresh entropy goes through this.
  withEntropy = f: E.Random.bytes {
    length = 40; # 16 salt + 24 nonce
    onSuccess = { bytes }: s: f bytes s;
    onError = { error }: s: fail "No entropy available: ${error}" s;
  };

  # Write keystore `k` to its mode's namespace; run `after` once that succeeded
  # (used to wipe the old namespace only after the new one is safely written).
  save = s: k: entropy: after:
    let
      sealed = builtins.tryEval (crypto.seal {
        plaintext = builtins.toJSON k.keys;
        passphrase = k.passphrase;
        inherit entropy;
      });
    in
    if k.mode == "plain" then
      step (put s k) (E.Storage.set {
        namespace = nsPlain; key = vaultKey; value = k.keys;
        onSuccess = s2: step s2 after;
        onError = storeFailed;
      })
    else if sealed.success then
      step (put s (k // { vault = sealed.value; })) (E.Storage.set {
        namespace = nsEncrypted; key = vaultKey; value = sealed.value;
        onSuccess = s2: step s2 after;
        onError = storeFailed;
      })
    else
      done (put s (k // { error = "Encryption failed."; }));

  validateNew = k:
    if builtins.stringLength k.draft.pass < cfg.minPassphraseLength then
      "Passphrase must be at least ${toString cfg.minPassphraseLength} characters."
    else if k.draft.pass != k.draft.pass2 then
      "Passphrases do not match."
    else null;

  # ── effects exposed to the app ───────────────────────────────────────
  boot = E.Storage.get {
    namespace = nsEncrypted; key = vaultKey;
    onSuccess = { value }: s:
      done (upd (k: k // { phase = "locked"; mode = "encrypted"; vault = value; }) s);
    onError = _: s: step s (E.Storage.get {
      namespace = nsPlain; key = vaultKey;
      onSuccess = { value }: s2:
        done (upd (k: k // { phase = "ready"; mode = "plain"; keys = value; }) s2);
      onError = _: s2: done (upd (k: k // { phase = "setup"; }) s2);
    });
  };

  addSecret = { name, secret }: withEntropy (entropy: s:
    let k = slice s; in
    if k.phase != "ready" then fail "Keystore is locked." s
    else save s (k // { keys = k.keys // { ${name} = secret; }; error = null; }) entropy E.Noop);

  removeSecret = name: withEntropy (entropy: s:
    let k = slice s; in
    if k.phase != "ready" then fail "Keystore is locked." s
    else save s (k // { keys = removeAttrs k.keys [ name ]; }) entropy E.Noop);

  lock = s:
    let k = slice s; in
    if k.mode == "encrypted" && k.phase == "ready" then
      done (put s (k // { phase = "locked"; passphrase = null; keys = { }; draft = noDraft; }))
    else done s;

  # ── handlers used by the built-in UI ─────────────────────────────────
  setupPlain = s:
    save s (slice s // {
      mode = "plain"; phase = "ready"; keys = { }; vault = null; error = null; draft = noDraft;
    }) null E.Noop;

  # setup (no keys yet) and "encrypt existing plain keystore" are the same flow
  makeEncrypted = s:
    let problem = validateNew (slice s); in
    if problem != null then fail problem s
    else step s (withEntropy (entropy: s2:
      let k2 = slice s2; in
      save s2 (k2 // {
        mode = "encrypted"; phase = "ready"; passphrase = k2.draft.pass;
        draft = noDraft; error = null;
      }) entropy (E.Storage.clear { namespace = nsPlain; })));

  changePassphrase = s:
    let
      k = slice s;
      problem = if k.draft.old != k.passphrase then "Current passphrase is wrong." else validateNew k;
    in
    if problem != null then fail problem s
    else step s (withEntropy (entropy: s2:
      let k2 = slice s2; in
      save s2 (k2 // { passphrase = k2.draft.pass; draft = noDraft; error = null; }) entropy E.Noop));

  removeEncryption = s:
    let k = slice s; in
    if k.draft.old != k.passphrase then fail "Current passphrase is wrong." s
    else save s (k // {
      mode = "plain"; passphrase = null; vault = null; draft = noDraft; error = null;
    }) null (E.Storage.clear { namespace = nsEncrypted; });

  unlock = s:
    let
      k = slice s;
      opened = builtins.tryEval (crypto.open { blob = k.vault; passphrase = k.draft.pass; });
    in
    if !opened.success then fail "Wrong passphrase." s
    else done (put s (k // {
      phase = "ready"; passphrase = k.draft.pass; keys = builtins.fromJSON opened.value;
      draft = noDraft; error = null;
    }));

  # ── UI ───────────────────────────────────────────────────────────────
  errorText = lib.optional (ks.error != null)
    (UI.Text { id = "ks-error"; text = "⚠ ${ks.error}"; });

  passInput = { id, field, placeholder }: UI.TextInput {
    inherit id placeholder;
    type = "password";
    value = ks.draft.${field};
    onInput = val: setDraft field val;
  };

  setupPrompt = UI.ColumnLayout {
    id = "ks-setup"; spacing = 10;
    children = [
      (UI.Text { id = "ks-setup-title"; text = "Protect your keys"; style = "heading"; })
      (UI.Text { id = "ks-setup-hint"; text = "Choose how secrets are stored on this device."; })
      (passInput { id = "ks-setup-pass"; field = "pass"; placeholder = "New passphrase"; })
      (passInput { id = "ks-setup-pass2"; field = "pass2"; placeholder = "Repeat passphrase"; })
      (UI.Button { id = "ks-setup-enc"; text = "🔒 Use encrypted keystore"; onClick = makeEncrypted; })
    ]
    ++ lib.optional cfg.allowPlain
      (UI.Button { id = "ks-setup-plain"; text = "Store without encryption"; variant = "outlined"; onClick = setupPlain; })
    ++ errorText;
  };

  unlockPrompt = UI.ColumnLayout {
    id = "ks-unlock"; spacing = 10;
    children = [
      (UI.Text { id = "ks-unlock-title"; text = "Keystore locked"; style = "heading"; })
      (passInput { id = "ks-unlock-pass"; field = "pass"; placeholder = "Passphrase"; })
      (UI.Button { id = "ks-unlock-btn"; text = "🔓 Unlock"; onClick = unlock; })
    ] ++ errorText;
  };

  # `child` is a lazy argument: when the gate is closed it is never evaluated.
  gate = child:
    if ks.phase == "ready" then child
    else if ks.phase == "booting" then UI.Text { id = "ks-booting"; text = "Opening keystore…"; }
    else if ks.phase == "locked" then unlockPrompt
    else setupPrompt;

  configPanel =
    if ks.phase != "ready" then
      UI.Text { id = "ks-cfg-locked"; text = "Keystore is locked."; }
    else UI.ColumnLayout {
      id = "ks-cfg"; spacing = 8;
      children =
        [ (UI.Text { id = "ks-cfg-title"; text = "Keystore: ${ks.mode}"; style = "heading"; }) ]
        ++ (if ks.mode == "plain" then [
          (UI.Text { id = "ks-cfg-hint"; text = "Secrets are stored unencrypted."; })
          (passInput { id = "ks-cfg-pass"; field = "pass"; placeholder = "New passphrase"; })
          (passInput { id = "ks-cfg-pass2"; field = "pass2"; placeholder = "Repeat passphrase"; })
          (UI.Button { id = "ks-cfg-encrypt"; text = "🔒 Encrypt keystore"; onClick = makeEncrypted; })
        ] else [
          (passInput { id = "ks-cfg-old"; field = "old"; placeholder = "Current passphrase"; })
          (passInput { id = "ks-cfg-pass"; field = "pass"; placeholder = "New passphrase"; })
          (passInput { id = "ks-cfg-pass2"; field = "pass2"; placeholder = "Repeat new passphrase"; })
          (UI.Button { id = "ks-cfg-change"; text = "Change passphrase"; onClick = changePassphrase; })
          (UI.Button { id = "ks-cfg-lock"; text = "Lock now"; variant = "outlined"; onClick = lock; })
        ] ++ lib.optional cfg.allowPlain
          (UI.Button { id = "ks-cfg-plain"; text = "Remove encryption"; variant = "text"; onClick = removeEncryption; }))
        ++ errorText;
    };
in
{
  options.services.keystore = {
    available = mkOption { type = types.bool; readOnly = true; description = "True when keys are usable."; };
    mode = mkOption { type = types.nullOr types.str; readOnly = true; };
    keys = mkOption { type = types.attrsOf types.str; readOnly = true; };
    Effects = mkOption { type = types.lazyAttrsOf types.raw; readOnly = true; };
    actions = mkOption { type = types.lazyAttrsOf types.raw; readOnly = true; };
    UI = mkOption { type = types.lazyAttrsOf types.raw; readOnly = true; };
  };

  config.services.keystore = {
    available = ks.phase == "ready";
    mode = ks.mode;
    keys = if ks.phase == "ready" then ks.keys else { };
    Effects = { inherit boot addSecret removeSecret; };
    actions = { inherit lock; };
    UI = { inherit gate; Config = configPanel; };
  };
}