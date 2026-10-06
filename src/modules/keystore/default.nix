{ lib, config, ... }: {

  options.keystore.enable = lib.mkEnableOption "Enable the keystore module.";
  config = {
    view = lib.mkIf config.keystore.enable  (import ./view.nix);
  }
}
