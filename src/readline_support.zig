const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");

pub const enabled = build_options.enable_readline and builtin.os.tag != .windows and builtin.os.tag != .wasi;

const c = if (enabled) @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("readline/readline.h");
    @cInclude("readline/history.h");
}) else struct {};

var history_initialized = false;

fn ensureHistoryInitialized() void {
    if (!enabled) return;
    if (history_initialized) return;
    c.using_history();
    history_initialized = true;
}

pub fn isAvailable() bool {
    return enabled;
}

pub fn addHistory(allocator: std.mem.Allocator, line: []const u8) !void {
    if (!enabled or line.len == 0) return;

    ensureHistoryInitialized();

    const line_z = try allocator.dupeZ(u8, line);
    defer allocator.free(line_z);
    _ = c.add_history(line_z.ptr);
}

pub fn readLine(allocator: std.mem.Allocator, prompt: []const u8) !?[]u8 {
    if (!enabled) return error.ReadlineUnavailable;

    ensureHistoryInitialized();

    const prompt_z = try allocator.dupeZ(u8, prompt);
    defer allocator.free(prompt_z);

    const raw_line = c.readline(prompt_z.ptr) orelse return null;
    defer c.free(@ptrCast(raw_line));

    return try allocator.dupe(u8, std.mem.span(raw_line));
}

test "readline support availability matches build option" {
    try std.testing.expectEqual(build_options.enable_readline and builtin.os.tag != .windows and builtin.os.tag != .wasi, isAvailable());
}
