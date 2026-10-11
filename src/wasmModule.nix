# src/wasm-module.nix
#
# Build time:  zig { args, returns, body }  ->  compiles Zig to wasm (needs pkgs)
# Runtime:     the returned function only calls `wasm { bytecode; function; } args`
#
# The returned function must NOT capture pkgs or lib, otherwise wechselbalg's
# walker follows those captures into the package set and fails (pkgs.binaryen).
{ lib, pkgs, ... }:
let
  # ── Runtime wrapper ──────────────────────────────────────────────
  # Takes everything it needs as explicit parameters, so the closure it
  # returns captures only: wasm (primop), name, argNames, bytecode (strings).
  wrap =
    {
      wasm,
      name,
      argNames,
      bytecode,
    }:
    callArgs:
    if builtins.attrNames callArgs != argNames then
      throw "${name}: expected args [${toString argNames}], got [${toString (builtins.attrNames callArgs)}]"
    else
      let
        res = wasm {
          inherit bytecode;
          function = "call";
        } callArgs;
      in
      if res.success then res.data else throw "wasmModule [${name}]: ${res.error}";

  # ── Zig shim generation (build time only) ────────────────────────
  zigDecode =
    name: type:
    {
      base64 = ''const ${name} = try decodeB64(a, try strField(obj, "${name}")); _ = &${name};'';
      str = ''const ${name} = try strField(obj, "${name}"); _ = &${name};'';
      int = ''const ${name} = try intField(obj, "${name}"); _ = &${name};'';
    }
    .${type} or (throw "wasmModule.zig: unknown arg type '${type}'");

  zigParam =
    name: type:
    {
      base64 = "${name}: []const u8";
      str = "${name}: []const u8";
      int = "${name}: i64";
    }
    .${type} or (throw "wasmModule.zig: unknown arg type '${type}'");

  # how the impl's return value becomes the "data" field of the envelope
  zigEncode =
    returns:
    {
      base64 = ''
        const enc = std.base64.standard.Encoder;
        const buf = try a.alloc(u8, enc.calcSize(result.len));
        const text = enc.encode(buf, result);
        const q = try quote(a, text);
        return ok(a, q);
      '';
      str = "return ok(a, try quote(a, result));";
      json = "return ok(a, result);"; # body returns JSON text
    }
    .${returns} or (throw "wasmModule.zig: unknown return type '${returns}'");

  # Compile to wasm and return it as a base64 string.
  build =
    {
      name,
      args,
      returns,
      body,
      initialMemory,
    }:
    let
      argNames = builtins.attrNames args;

      source = pkgs.writeText "${name}.zig" ''
        const std = @import("std");
        const Allocator = std.mem.Allocator;

        fn impl(a: Allocator, ${lib.concatStringsSep ", " (lib.mapAttrsToList zigParam args)}) ![]const u8 {
        ${body}
        }

        fn strField(obj: std.json.ObjectMap, k: []const u8) ![]const u8 {
            const v = obj.get(k) orelse return error.MissingArg;
            return switch (v) { .string => |s| s, else => error.BadArg };
        }
        fn intField(obj: std.json.ObjectMap, k: []const u8) !i64 {
            const v = obj.get(k) orelse return error.MissingArg;
            return switch (v) { .integer => |i| i, else => error.BadArg };
        }
        fn decodeB64(a: Allocator, s: []const u8) ![]u8 {
            const dec = std.base64.standard.Decoder;
            const out = try a.alloc(u8, try dec.calcSizeForSlice(s));
            try dec.decode(out, s);
            return out;
        }
        fn concat(a: Allocator, parts: []const []const u8) ![*:0]const u8 {
            var n: usize = 0;
            for (parts) |p| n += p.len;
            const out = try a.alloc(u8, n + 1);
            var i: usize = 0;
            for (parts) |p| {
                @memcpy(out[i..][0..p.len], p);
                i += p.len;
            }
            out[n] = 0;
            return out[0..n :0];
        }
        fn quote(a: Allocator, s: []const u8) ![]const u8 {
            const hex = "0123456789abcdef";
            var n: usize = 2;
            for (s) |c| n += switch (c) { '"', '\\' => 2, 0...31 => 6, else => 1 };
            const out = try a.alloc(u8, n);
            var i: usize = 0;
            out[i] = '"'; i += 1;
            for (s) |c| switch (c) {
                '"', '\\' => { out[i] = '\\'; out[i + 1] = c; i += 2; },
                0...31 => {
                    @memcpy(out[i..][0..4], "\\u00");
                    out[i + 4] = hex[c >> 4];
                    out[i + 5] = hex[c & 15];
                    i += 6;
                },
                else => { out[i] = c; i += 1; },
            };
            out[i] = '"';
            return out;
        }
        fn ok(a: Allocator, data_json: []const u8) ![*:0]const u8 {
            return concat(a, &.{ "{\"success\":true,\"data\":", data_json, "}" });
        }
        fn fail(a: Allocator, msg: []const u8) [*:0]const u8 {
            return concat(a, &.{ "{\"success\":false,\"error\":\"", msg, "\"}" }) catch
                "{\"success\":false,\"error\":\"OutOfMemory\"}";
        }

        fn run(a: Allocator, input: []const u8) ![*:0]const u8 {
            const parsed = try std.json.parseFromSliceLeaky(std.json.Value, a, input, .{});
            const obj = switch (parsed) { .object => |o| o, else => return error.BadArgs };
            ${lib.concatStringsSep "\n    " (lib.mapAttrsToList zigDecode args)}
            const result = impl(a, ${lib.concatStringsSep ", " argNames}) catch |e| return fail(a, @errorName(e));
            ${zigEncode returns}
        }

        export fn malloc(n: usize) ?[*]u8 {
            const s = std.heap.wasm_allocator.alloc(u8, n) catch return null;
            return s.ptr;
        }
        export fn call(input: [*:0]const u8) ?[*:0]const u8 {
            var arena = std.heap.ArenaAllocator.init(std.heap.wasm_allocator);
            const a = arena.allocator();
            return run(a, std.mem.span(input)) catch |e| fail(a, @errorName(e));
        }
      '';

      wasmDrv =
        pkgs.runCommand "${name}.wasm"
          {
            nativeBuildInputs = [
              pkgs.zig
              pkgs.binaryen
            ];
          }
          ''
            export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-global ZIG_LOCAL_CACHE_DIR=$TMPDIR/zig-local
            zig build-exe ${source} -target wasm32-freestanding -O ReleaseSmall -fno-entry \
              --export=malloc --export=call --export-memory \
              --initial-memory=${toString initialMemory} -femit-bin=$TMPDIR/out.wasm
            wasm-opt -Oz --enable-bulk-memory --enable-sign-ext --enable-nontrapping-float-to-int \
              $TMPDIR/out.wasm -o $out         
          '';
    in
    builtins.readFile (pkgs.runCommand "${name}.b64" { } "base64 -w0 ${wasmDrv} > $out");
in
{
  zig =
    {
      name ? "zigConvertedFunction",
      args,
      returns,
      body,
      # Must be larger than the working set (e.g. > 16 MiB for Argon2 m=16384).
      # Every call copies this much memory to restore the pristine snapshot,
      # so don't make it bigger than needed.
      initialMemory ? 8388608,
    }:
    wrap {
      inherit name;
      wasm = lib.wasm;
      argNames = builtins.attrNames args;
      bytecode = build {
        inherit
          name
          args
          returns
          body
          initialMemory
          ;
      };
    };
}
