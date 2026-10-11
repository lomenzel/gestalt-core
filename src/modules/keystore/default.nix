{ lib, config, wasmModule, ... }:
let
  cfg = config.services.keystore;
  crypto = import ./crypto.nix { inherit lib wasmModule; };
in
{
  options.services.keystore = {
    enable = lib.mkEnableOption "the keystore module";

    allowPlain = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Offer the unencrypted mode in setup and in the config panel.";
    };

    minPassphraseLength = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8;
    };
    _crypto = lib.mkOption {
      type = lib.types.raw;
      internal = true;
      readOnly = true;
    };
  };

  config = lib.mkIf cfg.enable {
    initialState._gestaltInternal.keystore = {
      phase = "booting"; # booting | setup | locked | ready
      mode = null; # null | "plain" | "encrypted"
      vault = null; # last sealed blob, so unlock needs no storage read
      passphrase = null; # only while ready + encrypted
      keys = { }; # name -> secret, decrypted, in memory only
      draft = {
        pass = "";
        pass2 = "";
        old = "";
      };
      error = null;
    };

    services.keystore._crypto = crypto;

    # the view part is only evaluated when the module is enabled
    view = import ./view.nix cfg;
  };
}
