const std = @import("std");
const transpile = @import("transpile.zig");
const eel = @import("eel.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip();

    const out_path = args.next() orelse {
        std.debug.print("usage: signal-emit <out.zig> <model.wmfx>\n", .{});
        return error.Usage;
    };
    const model_path = args.next() orelse {
        std.debug.print("usage: signal-emit <out.zig> <model.wmfx>\n", .{});
        return error.Usage;
    };

    const vm = eel.c.intranquil_eel_vm_create() orelse return error.VmCreateFailed;
    defer eel.c.intranquil_eel_vm_destroy(vm);

    if (std.fs.path.dirname(out_path)) |dir| {
        try std.fs.cwd().makePath(dir);
    }

    var file = try std.fs.cwd().createFile(out_path, .{});
    defer file.close();
    var buf: [8192]u8 = undefined;
    var writer = file.writer(&buf);

    try transpile.emitJsfxPath(allocator, vm, model_path, &writer.interface, .{
        .source_label = "koru-libs/signal codegen weld",
        .include_transport = false,
    });
    try writer.interface.flush();

    std.debug.print("Wrote {s}\n", .{out_path});
}
