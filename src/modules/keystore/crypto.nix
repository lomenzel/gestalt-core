{ lib, wasmModule }:
let
  # passphrase + 16-byte salt -> 32-byte key (argon2id, 16 MiB, t=3)
  kdf = ''
    var key: [32]u8 = undefined;
    try std.crypto.pwhash.argon2.kdf(a, &key, passphrase, salt, .{ .t = 3, .m = 16384, .p = 1 }, .argon2id, std.Io.failing);
  '';
in
{
  # blob = version(1) || salt(16) || nonce(24) || ciphertext || tag(16), base64
  # entropy = 40 random bytes from Effects.Random (16 salt + 24 nonce)
  seal = wasmModule.zig {
    args = {
      plaintext = "str";
      passphrase = "str";
      entropy = "base64";
    };
    returns = "base64";
    body = ''
      const Aead = std.crypto.aead.chacha_poly.XChaCha20Poly1305;
      if (entropy.len < 40) return error.ShortEntropy;
      const salt = entropy[0..16];
      const nonce: [Aead.nonce_length]u8 = entropy[16..40].*;
      ${kdf}
      const out = try a.alloc(u8, 41 + plaintext.len + Aead.tag_length);
      out[0] = 1; // format version, also bound as AAD
      @memcpy(out[1..17], salt);
      @memcpy(out[17..41], &nonce);
      var tag: [Aead.tag_length]u8 = undefined;
      Aead.encrypt(out[41 .. 41 + plaintext.len], &tag, plaintext, out[0..1], nonce, key);
      @memcpy(out[41 + plaintext.len ..], &tag);
      return out;
    '';
  };

  open = wasmModule.zig {
    args = {
      blob = "base64";
      passphrase = "str";
    };
    returns = "str";
    body = ''
      const Aead = std.crypto.aead.chacha_poly.XChaCha20Poly1305;
      if (blob.len < 41 + Aead.tag_length or blob[0] != 1) return error.Malformed;
      const salt = blob[1..17];
      const nonce: [Aead.nonce_length]u8 = blob[17..41].*;
      const ct = blob[41 .. blob.len - Aead.tag_length];
      const tag: [Aead.tag_length]u8 = blob[blob.len - Aead.tag_length ..][0..Aead.tag_length].*;
      ${kdf}
      const out = try a.alloc(u8, ct.len);
      try Aead.decrypt(out, ct, tag, blob[0..1], nonce, key);
      return out;
    '';
  };
}
