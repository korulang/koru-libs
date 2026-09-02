const std = @import("std");
const wmfx = @import("wmfx_model");
const koru = @import("koru_model");
const oracle = @import("oracle");

pub fn main() !void {
    const bars = [_]oracle.Bar{
        .{ .idx = 0, .iso = "t0", .pass_rate = 90, .passed = 0, .in_scope = 0, .failed = 0, .todo = 0, .in_sample = true },
        .{ .idx = 1, .iso = "t1", .pass_rate = 85, .passed = 0, .in_scope = 0, .failed = 0, .todo = 0, .in_sample = true },
        .{ .idx = 2, .iso = "t2", .pass_rate = 70, .passed = 0, .in_scope = 0, .failed = 0, .todo = 0, .in_sample = false },
    };

    var seq: [20]oracle.Bar = undefined;
    @memcpy(seq[0..3], bars[0..3]);
    var i: usize = 3;
    while (i < seq.len) : (i += 1) {
        seq[i] = .{
            .idx = @intCast(i),
            .iso = "t stall",
            .pass_rate = 70,
            .passed = 0,
            .in_scope = 0,
            .failed = 0,
            .todo = 0,
            .in_sample = false,
        };
    }

    var wmfx_state: wmfx.State = .{};
    var koru_state: koru.State = .{};
    _ = wmfx.init(&wmfx_state);
    _ = koru.init(&koru_state);

    var ref: oracle.OracleState = .{};
    var wmfx_oracle_mismatch: u32 = 0;
    var koru_oracle_mismatch: u32 = 0;
    var cross_mismatch: u32 = 0;
    var oos_fires: u32 = 0;

    for (seq) |bar| {
        wmfx_state.pass_rate = bar.pass_rate;
        koru_state.pass_rate = bar.pass_rate;
        _ = wmfx.block(&wmfx_state);
        _ = koru.block(&koru_state);

        const ref_out = oracle.step(&ref, bar);

        if (@abs(wmfx_state.alarm - ref_out.alarm) > 1e-9) wmfx_oracle_mismatch += 1;
        if (@abs(wmfx_state.dip_ticks - ref_out.dip_ticks) > 1e-9) wmfx_oracle_mismatch += 1;
        if (@abs(koru_state.alarm - ref_out.alarm) > 1e-9) koru_oracle_mismatch += 1;
        if (@abs(koru_state.dip_ticks - ref_out.dip_ticks) > 1e-9) koru_oracle_mismatch += 1;

        if (@abs(wmfx_state.alarm - koru_state.alarm) > 1e-9) cross_mismatch += 1;
        if (@abs(wmfx_state.dip_ticks - koru_state.dip_ticks) > 1e-9) cross_mismatch += 1;
        if (@abs(wmfx_state.peak - koru_state.peak) > 1e-9) cross_mismatch += 1;
        if (@abs(wmfx_state.drawdown - koru_state.drawdown) > 1e-9) cross_mismatch += 1;
        if (@abs(wmfx_state.surprise - koru_state.surprise) > 1e-9) cross_mismatch += 1;

        if (!bar.in_sample and wmfx_state.alarm >= 0.5) oos_fires += 1;
    }

    if (wmfx_oracle_mismatch > 0) {
        std.debug.print("FAIL: reference emit diverged from oracle on {d} check(s)\n", .{wmfx_oracle_mismatch});
        return error.ReferenceOracleMismatch;
    }
    if (koru_oracle_mismatch > 0) {
        std.debug.print("FAIL: Koru→EEL emit diverged from oracle on {d} check(s)\n", .{koru_oracle_mismatch});
        return error.KoruOracleMismatch;
    }
    if (cross_mismatch > 0) {
        std.debug.print("FAIL: Koru→EEL emit diverged from reference emit on {d} field check(s)\n", .{cross_mismatch});
        return error.CrossMismatch;
    }
    if (oos_fires == 0) {
        std.debug.print("FAIL: sustained inhale never tripped alarm\n", .{});
        return error.NoAlarm;
    }

    std.debug.print(
        "PASS: Koru→EEL emit ≡ reference emit ({d} OOS fire(s), 0 cross/oracle mismatches)\n",
        .{oos_fires},
    );
}
