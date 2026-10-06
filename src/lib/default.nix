{ lib, ... }:
let
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
    .${type};

  # how the impl's return value becomes the "data" field of the envelope
  zigEncode =
    {
      base64 = ''
        const enc = std.base64.standard.Encoder;
        const buf = try a.alloc(u8, enc.calcSize(result.len));
        const text = enc.encode(buf, result);
        return ok(a, try std.fmt.allocPrint(a, "\"{s}\"", .{text}));'';
      str = "return ok(a, try quote(a, result));";
      json = "return ok(a, result);"; # body returns JSON text
    }
    .${returns} or (throw "unknown return type");
in
{

  mkGestaltIR =
    { modules, ... }:
    let
      ir =
        (lib.evalModules {
          modules = modules ++ [
            ../modules/default.nix
          ];
          specialArgs = {
            inherit lib;
          };
        }).config;
    in
    {
      inherit (ir)
        meta
        initialState
        showcaseState
        veilid
        ;
      view = ir._view;
    };
  wasmModule.zig =
    pkgs:
    {
      name ? "zigConvertedFunction",
      args,
      returns,
      body,
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
        fn quote(a: Allocator, s: []const u8) ![]const u8 {
            var l = std.ArrayList(u8).init(a);
            try l.append('"');
            for (s) |c| switch (c) {
                '"' => try l.appendSlice("\\\""),
                '\\' => try l.appendSlice("\\\\"),
                0...31 => try l.writer().print("\\u{x:0>4}", .{c}),
                else => try l.append(c),
            };
            try l.append('"');
            return l.items;
        }
        fn ok(a: Allocator, data_json: []const u8) ![*:0]const u8 {
            return try std.fmt.allocPrintZ(a, "{{\"success\":true,\"data\":{s}}}", .{data_json});
        }
        fn fail(a: Allocator, msg: []const u8) [*:0]const u8 {
            return std.fmt.allocPrintZ(a, "{{\"success\":false,\"error\":\"{s}\"}}", .{msg}) catch @trap();
        }

        fn run(a: Allocator, input: []const u8) ![*:0]const u8 {
            const parsed = try std.json.parseFromSliceLeaky(std.json.Value, a, input, .{});
            const obj = switch (parsed) { .object => |o| o, else => return error.BadArgs };
            ${lib.concatStringsSep "\n    " (lib.mapAttrsToList zigDecode args)}
            const result = impl(a, ${lib.concatStringsSep ", " argNames}) catch |e| return fail(a, @errorName(e));
            ${zigEncode}
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

      wasm =
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
              --export=malloc --export=call --initial-memory=8388608 -femit-bin=$TMPDIR/out.wasm
            wasm-opt -Oz $TMPDIR/out.wasm -o $out
          '';

      b64 = builtins.readFile (pkgs.runCommand "${name}.b64" { } "base64 -w0 ${wasm} > $out");
    in
    callArgs:
    assert lib.assertMsg (
      builtins.attrNames callArgs == argNames
    ) "${name}: expected args [${toString argNames}], got [${toString (builtins.attrNames callArgs)}]";
    let
      res = lib.wasm {
        bytecode = b64;
        function = "call";
      } callArgs;
    in
    if res.success then res.data else throw "wasmModule [${name}]: ${res.error}";
}
