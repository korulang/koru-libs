// Signal emit (scalar wire): koru-libs/signal Koru model emit
// Auto-generated from EEL2. Do not edit by hand.

const std = @import("std");
extern fn pow(x: f64, y: f64) f64;

pub const State = struct {
    floor: f64 = 0,
    alarm: f64 = 0,
    pass_rate: f64 = 0,
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
// wmfx:reads floor<percent>
// wmfx:writes floor<percent>
pub fn init(s: *State) f64 {
    return blk0: { const v0 = @as(f64, 8e1); s.floor = v0; break :blk0 s.floor; };
}

// wmfx:unit block
// wmfx:wire scalar
// wmfx:reads alarm<1>, floor<percent>, pass_rate<percent>
// wmfx:writes alarm<1>
pub fn block(s: *State) f64 {
    return blk0: { const v0 = (if (((if (s.pass_rate < s.floor) @as(f64, 1.0) else @as(f64, 0.0))) != 0.0) (@as(f64, 1e0)) else (@as(f64, 0e0))); s.alarm = v0; break :blk0 s.alarm; };
}

