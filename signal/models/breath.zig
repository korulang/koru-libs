// Signal emit (scalar wire): koru-libs/signal codegen weld
// Auto-generated from EEL2. Do not edit by hand.

const std = @import("std");
extern fn pow(x: f64, y: f64) f64;

pub const State = struct {
    peak: f64 = 0,
    dip_ticks: f64 = 0,
    depth_floor: f64 = 0,
    dur_threshold: f64 = 0,
    pass_rate: f64 = 0,
    drawdown: f64 = 0,
    alarm: f64 = 0,
    surprise: f64 = 0,
};

noinline fn __stub_zero() f64 { return 0; }
noinline fn __discard(_: f64) void {}

// denormal_filter_double2 from WDL denormal.h:109-112 — the bit-pattern
// trick NSEEL2's portable bytecode applies to every ASSIGN/ADD_OP/SUB_OP/
// MUL_OP/DIV_OP result via glue_port.h:737/740/749/752/776/788. Zeroes
// subnormals AND, as a side effect of the (exp+1)&mask scheme, NaN/±Inf
// (exp=0x7ff overflows the exponent field, leaving 0 after mask).
fn denormalFilter(a: f64) f64 {
    // FP-domain equivalent of WDL's bit-pattern denormal_filter_double2:
    // keep `a` iff its exponent field is a normal value [1, 0x7fe],
    // i.e. |a| in [DBL_MIN, DBL_MAX]. Zeroes subnormals (exp 0, incl
    // true zero -> 0), and NaN/+/-Inf (NaN: both compares unordered ->
    // false -> 0; Inf: |a| > DBL_MAX -> 0). Bit-identical to the mask
    // scheme but stays in FP registers -- no @bitCast / fmov x<-d
    // cross-domain transfer, which is the per-assign cost the NSEEL2
    // JIT avoids (it tests the already-stored bits from memory).
    const fa = @abs(a);
    return if (fa >= 2.2250738585072014e-308 and fa <= 1.7976931348623157e308) a else 0.0;
}

pub const Slider = struct {
    id: u8,
    var_name: []const u8,
    def: f64,
    min: f64,
    max: f64,
    inc: f64,
    desc: []const u8,
    is_enum: bool = false,
    enum_names: []const []const u8 = &.{},
    shape: u8 = 0,
    shape_modifier: f64 = 0,
    initially_visible: bool = true,
};

pub const sliders: []const Slider = &.{
};

pub fn setSlider(s: *State, id: u8, value: f64) void {
    _ = s;
    _ = id;
    _ = value;
}

// wmfx:unit init
// wmfx:wire scalar
// wmfx:reads depth_floor<percent>, dip_ticks<1>, dur_threshold<1>, peak<percent>
// wmfx:writes depth_floor<percent>, dip_ticks<1>, dur_threshold<1>, peak<percent>
pub fn init(s: *State) f64 {
    return blk0: { __discard(blk1: { const v1 = @as(f64, 0e0); s.peak = v1; break :blk1 s.peak; }); break :blk0 blk2: { __discard(blk3: { const v3 = @as(f64, 0e0); s.dip_ticks = v3; break :blk3 s.dip_ticks; }); break :blk2 blk4: { __discard(blk5: { const v5 = @as(f64, 8e0); s.depth_floor = v5; break :blk5 s.depth_floor; }); break :blk4 blk6: { const v6 = @as(f64, 1.8e1); s.dur_threshold = v6; break :blk6 s.dur_threshold; }; }; }; };
}

// wmfx:unit block
// wmfx:wire scalar
// wmfx:reads alarm<1>, depth_floor<percent>, dip_ticks<1>, drawdown<percent>, dur_threshold<1>, pass_rate<percent>, peak<percent>, surprise<1>
// wmfx:writes alarm<1>, dip_ticks<1>, drawdown<percent>, peak<percent>, surprise<1>
pub fn block(s: *State) f64 {
    return blk0: { __discard(blk1: { const v1 = (if (((if (s.pass_rate > s.peak) @as(f64, 1.0) else @as(f64, 0.0))) != 0.0) (s.pass_rate) else (s.peak)); s.peak = v1; break :blk1 s.peak; }); break :blk0 blk2: { __discard(blk3: { const v3 = denormalFilter((s.peak - s.pass_rate)); s.drawdown = v3; break :blk3 s.drawdown; }); break :blk2 blk4: { __discard(blk5: { const v5 = (if (((if (s.drawdown >= s.depth_floor) @as(f64, 1.0) else @as(f64, 0.0))) != 0.0) ((s.dip_ticks + @as(f64, 1e0))) else (@as(f64, 0e0))); s.dip_ticks = v5; break :blk5 s.dip_ticks; }); break :blk4 blk6: { __discard(blk7: { const v7 = (if (((if (s.dip_ticks >= s.dur_threshold) @as(f64, 1.0) else @as(f64, 0.0))) != 0.0) (@as(f64, 1e0)) else (@as(f64, 0e0))); s.alarm = v7; break :blk7 s.alarm; }); break :blk6 blk8: { const v8 = s.dip_ticks; s.surprise = v8; break :blk8 s.surprise; }; }; }; }; };
}

