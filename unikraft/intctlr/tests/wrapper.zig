// C-ABI seam between Unikraft's boot path and Koru's emitted flows.
//
// Deliberately does NOT call output_emitted.zig's `pub fn main` — that epilogue
// ends in std.process.exit for the leak check, which has no implementation on
// x86_64-freestanding. What is below is exactly what `main` does before that
// point.
//
// The flow list is derived at comptime rather than written out, because it is
// derivable and because getting it wrong is silent. `koruc` emits one `flowN`
// per top-level flow in source order, and `@typeInfo` already knows how many
// there are. Same technique `unikraft/mpi`'s wrapper.zig uses.
const std = @import("std");
const app = @import("output_emitted.zig");

export fn koru_main() void {
    app.main_module.koru_start_flow();
    inline for (0..1024) |i| {
        const name = std.fmt.comptimePrint("flow{d}", .{i});
        if (!@hasDecl(app.main_module, name)) break;
        @field(app.main_module, name)();
    }
    app.main_module.koru_end_flow();
}
