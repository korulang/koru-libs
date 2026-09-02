const std = @import("std");

pub const Bar = struct {
    idx: u32,
    iso: []const u8,
    pass_rate: f64,
    passed: u32,
    in_scope: u32,
    failed: u32,
    todo: u32,
    in_sample: bool,
};

pub const OracleState = struct {
    peak: f64 = 0,
    dip_ticks: f64 = 0,
    depth_floor: f64 = 8,
    dur_threshold: f64 = 18,
};

pub const OracleOut = struct {
    alarm: f64,
    dip_ticks: f64,
};

pub fn step(s: *OracleState, bar: Bar) OracleOut {
    if (bar.pass_rate > s.peak) s.peak = bar.pass_rate;
    const drawdown = s.peak - bar.pass_rate;
    s.dip_ticks = if (drawdown >= s.depth_floor) s.dip_ticks + 1 else 0;
    const alarm: f64 = if (s.dip_ticks >= s.dur_threshold) 1 else 0;
    return .{ .alarm = alarm, .dip_ticks = s.dip_ticks };
}
