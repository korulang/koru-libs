const std = @import("std");
const transpile = @import("transpile.zig");
const jsfx = @import("jsfx.zig");
const eel = @import("eel.zig");

const ParseError = error{
    Usage,
    ShapeNotFound,
    ConstNotFound,
    BlockNotFound,
    OutOfMemory,
};

fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\r\n");
}

fn findBlock(source: []const u8, keyword: []const u8) ParseError![]const u8 {
    var needle_buf: [32]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "{s} {{", .{keyword}) catch unreachable;
    const start = std.mem.indexOf(u8, source, needle) orelse return if (std.mem.eql(u8, keyword, "block"))
        ParseError.BlockNotFound
    else
        ParseError.ConstNotFound;
    var i = start + needle.len;
    var depth: u32 = 1;
    const body_start = i;
    while (i < source.len) : (i += 1) {
        switch (source[i]) {
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if (depth == 0) return trim(source[body_start..i]);
            },
            else => {},
        }
    }
    return if (std.mem.eql(u8, keyword, "block")) ParseError.BlockNotFound else ParseError.ConstNotFound;
}

fn findNamedBlock(source: []const u8, marker: []const u8) ?[]const u8 {
    const start = std.mem.indexOf(u8, source, marker) orelse return null;
    const open = std.mem.indexOfScalar(u8, source[start..], '{') orelse return null;
    var i = start + open + 1;
    var depth: u32 = 1;
    const body_start = i;
    while (i < source.len) : (i += 1) {
        switch (source[i]) {
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if (depth == 0) return trim(source[body_start..i]);
            },
            else => {},
        }
    }
    return null;
}

fn findShapeBody(source: []const u8) ParseError![]const u8 {
    const body = findNamedBlock(source, ":shape(") orelse return ParseError.ShapeNotFound;
    return body;
}

const LabeledField = struct {
    name: []const u8,
    unit: []const u8,
};

fn unitForField(name: []const u8) []const u8 {
    if (std.mem.endsWith(u8, name, "_rate")) return "percent";
    if (std.mem.eql(u8, name, "pass_rate")) return "percent";
    if (std.mem.eql(u8, name, "peak")) return "percent";
    if (std.mem.eql(u8, name, "drawdown")) return "percent";
    if (std.mem.eql(u8, name, "depth_floor")) return "percent";
    if (std.mem.eql(u8, name, "floor")) return "percent";
    if (std.mem.eql(u8, name, "dur_threshold")) return "1";
    if (std.mem.eql(u8, name, "dip_ticks")) return "1";
    if (std.mem.eql(u8, name, "alarm")) return "1";
    if (std.mem.eql(u8, name, "surprise")) return "1";
    return "1";
}

fn unitLabelFor(
    name: []const u8,
    shape_labels: []const LabeledField,
    slot_labels: []const LabeledField,
) []const u8 {
    for (shape_labels) |f| {
        if (std.mem.eql(u8, f.name, name)) return f.unit;
    }
    for (slot_labels) |f| {
        if (std.mem.eql(u8, f.name, name)) return f.unit;
    }
    return unitForField(name);
}

fn freeLabeledFields(allocator: std.mem.Allocator, fields: []const LabeledField) void {
    for (fields) |f| {
        allocator.free(f.name);
        allocator.free(f.unit);
    }
    allocator.free(fields);
}

fn appendUniqueField(allocator: std.mem.Allocator, names: *std.ArrayList([]const u8), name: []const u8) !void {
    for (names.items) |existing| {
        if (std.mem.eql(u8, existing, name)) return;
    }
    try names.append(allocator, try allocator.dupe(u8, name));
}

fn appendUniqueLabeled(
    allocator: std.mem.Allocator,
    fields: *std.ArrayList(LabeledField),
    name: []const u8,
    unit: []const u8,
) !void {
    for (fields.items) |existing| {
        if (std.mem.eql(u8, existing.name, name)) return;
    }
    try fields.append(allocator, .{
        .name = try allocator.dupe(u8, name),
        .unit = try allocator.dupe(u8, unit),
    });
}

fn parseBracketField(line: []const u8) ?LabeledField {
    const t = trim(line);
    if (t.len == 0 or t[0] == '/') return null;
    if (std.mem.indexOfScalar(u8, t, '=') != null) return null;
    const open = std.mem.indexOfScalar(u8, t, '[') orelse return null;
    const close = std.mem.indexOfScalar(u8, t, ']') orelse return null;
    if (close <= open) return null;
    const name = trim(t[0..open]);
    const unit = trim(t[open + 1 .. close]);
    if (name.len == 0 or unit.len == 0) return null;
    return .{ .name = name, .unit = unit };
}

fn parseLabeledFields(allocator: std.mem.Allocator, body: []const u8) ![]LabeledField {
    var fields = std.ArrayList(LabeledField).empty;
    errdefer {
        for (fields.items) |f| {
            allocator.free(f.name);
            allocator.free(f.unit);
        }
        fields.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, body, '\n');
    while (lines.next()) |line| {
        const parsed = parseBracketField(line) orelse continue;
        try appendUniqueLabeled(allocator, &fields, parsed.name, parsed.unit);
    }
    return try fields.toOwnedSlice(allocator);
}

fn parseColonFields(allocator: std.mem.Allocator, body: []const u8) ![]const []const u8 {
    var names = std.ArrayList([]const u8).empty;
    errdefer {
        for (names.items) |f| allocator.free(f);
        names.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, body, '\n');
    while (lines.next()) |line| {
        const t = trim(line);
        if (t.len == 0 or t[0] == '/') continue;
        const colon = std.mem.indexOfScalar(u8, t, ':') orelse continue;
        const name = trim(t[0..colon]);
        if (name.len == 0) continue;
        try appendUniqueField(allocator, &names, name);
    }
    return try names.toOwnedSlice(allocator);
}

fn parseColonAssignments(allocator: std.mem.Allocator, body: []const u8) ![]const u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    var parts = std.mem.tokenizeAny(u8, body, ",\n");
    while (parts.next()) |part| {
        const t = trim(part);
        if (t.len == 0) continue;
        const colon = std.mem.indexOfScalar(u8, t, ':') orelse continue;
        const name = trim(t[0..colon]);
        const value = trim(t[colon + 1 ..]);
        if (name.len == 0 or value.len == 0) continue;
        try out.writer(allocator).print("{s} = {s};\n", .{ name, value });
    }
    if (out.items.len == 0) return error.ConstNotFound;
    return try out.toOwnedSlice(allocator);
}

fn parseOptionalColonAssignments(allocator: std.mem.Allocator, body: []const u8) ![]const u8 {
    return parseColonAssignments(allocator, body) catch |err| switch (err) {
        error.ConstNotFound => try allocator.dupe(u8, ""),
        else => |e| return e,
    };
}

fn stripTickSlotDeclarations(allocator: std.mem.Allocator, body: []const u8) ![]const u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    var lines = std.mem.splitScalar(u8, body, '\n');
    while (lines.next()) |line| {
        const t = trim(line);
        if (t.len == 0) continue;
        if (std.mem.indexOfScalar(u8, t, '[') != null and std.mem.indexOfScalar(u8, t, ']') != null) {
            const open = std.mem.indexOfScalar(u8, t, '[').?;
            const close = std.mem.indexOfScalar(u8, t, ']').?;
            if (close > open and trim(t[open + 1 .. close]).len > 0 and std.mem.indexOfScalar(u8, t, '=') == null) {
                continue;
            }
        }
        try out.appendSlice(allocator, t);
        if (!std.mem.endsWith(u8, t, ";")) try out.append(allocator, ';');
        try out.append(allocator, '\n');
    }
    return try out.toOwnedSlice(allocator);
}

pub fn emitKoruModelPath(
    allocator: std.mem.Allocator,
    vm: *eel.c.intranquil_eel_vm,
    model_path: []const u8,
    writer: anytype,
    options: @import("codegen.zig").EmitOptions,
) !void {
    const source = try std.fs.cwd().readFileAlloc(allocator, model_path, 1024 * 1024);
    defer allocator.free(source);

    const shape_body = try findShapeBody(source);
    const const_body = try findBlock(source, "const");
    const block_body = try findBlock(source, "block");
    const init_body = findNamedBlock(source, ":init(");

    const shape_labels = try parseLabeledFields(allocator, shape_body);
    defer freeLabeledFields(allocator, shape_labels);

    const slot_labels = try parseLabeledFields(allocator, block_body);
    defer freeLabeledFields(allocator, slot_labels);

    const const_fields = try parseColonFields(allocator, const_body);
    defer {
        for (const_fields) |f| allocator.free(f);
        allocator.free(const_fields);
    }

    const init_fields = if (init_body) |body| try parseColonFields(allocator, body) else @as([]const []const u8, &.{});
    defer {
        for (init_fields) |f| allocator.free(f);
        if (init_fields.len > 0) allocator.free(init_fields);
    }

    var all_fields = std.ArrayList([]const u8).empty;
    errdefer {
        for (all_fields.items) |f| allocator.free(f);
        all_fields.deinit(allocator);
    }
    for (shape_labels) |f| try appendUniqueField(allocator, &all_fields, f.name);
    for (const_fields) |f| try appendUniqueField(allocator, &all_fields, f);
    for (init_fields) |f| try appendUniqueField(allocator, &all_fields, f);
    for (slot_labels) |f| try appendUniqueField(allocator, &all_fields, f.name);

    const const_init = try parseColonAssignments(allocator, const_body);
    defer allocator.free(const_init);

    const scope_init = if (init_body) |body| try parseOptionalColonAssignments(allocator, body) else try allocator.dupe(u8, "");
    defer allocator.free(scope_init);

    const eel_block = try stripTickSlotDeclarations(allocator, block_body);
    defer allocator.free(eel_block);

    var eel_buf = std.ArrayList(u8).empty;
    errdefer eel_buf.deinit(allocator);

    for (all_fields.items) |field| {
        const unit = unitLabelFor(field, shape_labels, slot_labels);
        try eel_buf.writer(allocator).print("@unit {s}     {s}\n", .{ field, unit });
    }
    try eel_buf.appendSlice(allocator, "\n@init\n");
    try eel_buf.appendSlice(allocator, scope_init);
    try eel_buf.appendSlice(allocator, const_init);
    try eel_buf.appendSlice(allocator, "\n@block\n");
    try eel_buf.appendSlice(allocator, eel_block);
    try eel_buf.append(allocator, '\n');

    var parsed = try transpile.parseModule(allocator, vm, eel_buf.items);
    defer transpile.freeParsedModule(allocator, &parsed);

    try @import("codegen.zig").emitModule(
        allocator,
        vm,
        parsed.named_sections,
        parsed.sliders,
        parsed.sliders_owned.port_units,
        parsed.sliders_owned.transfer_rules,
        writer,
        options,
    );
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip();

    const out_path = args.next() orelse {
        std.debug.print("usage: signal-model-emit <out.zig> <model.koru.kz>\n", .{});
        return ParseError.Usage;
    };
    const model_path = args.next() orelse {
        std.debug.print("usage: signal-model-emit <out.zig> <model.koru.kz>\n", .{});
        return ParseError.Usage;
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

    try emitKoruModelPath(allocator, vm, model_path, &writer.interface, .{
        .source_label = "koru-libs/signal Koru model emit",
        .include_transport = false,
    });
    try writer.interface.flush();

    std.debug.print("Wrote {s}\n", .{out_path});
}
