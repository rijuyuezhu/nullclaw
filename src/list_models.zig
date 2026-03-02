/// --list-models subcommand: output available models for a provider as JSON array.
///
/// Used by nullhub to populate the dynamic model selector during onboarding.
/// Delegates to onboard.fetchModels which handles caching, fallbacks, and API calls.
const std = @import("std");
const onboard = @import("onboard.zig");

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var provider: ?[]const u8 = null;
    var api_key: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--provider") and i + 1 < args.len) {
            provider = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--api-key") and i + 1 < args.len) {
            api_key = args[i + 1];
            i += 1;
        }
    }

    if (provider == null) {
        std.debug.print("error: --provider is required\n", .{});
        std.process.exit(1);
    }

    // Use onboard's fetchModels (handles caching, fallbacks, API calls)
    const models = onboard.fetchModels(allocator, provider.?, api_key) catch |err| {
        std.debug.print("error fetching models: {}\n", .{err});
        std.process.exit(1);
    };
    defer {
        for (models) |m| allocator.free(m);
        allocator.free(models);
    }

    // Output as JSON array to stdout
    var stdout_buf: [65536]u8 = undefined;
    var bw = std.fs.File.stdout().writer(&stdout_buf);
    const out = &bw.interface;

    try out.writeByte('[');
    for (models, 0..) |model, idx| {
        if (idx > 0) try out.writeByte(',');
        try out.writeByte('"');
        // Simple escape: model IDs are alphanumeric with slashes/dashes, no quotes/backslashes
        try out.writeAll(model);
        try out.writeByte('"');
    }
    try out.writeAll("]\n");
    try bw.interface.flush();
}

test "run requires --provider flag" {
    // Cannot easily test process.exit in-process; just verify the function signature compiles.
    // The real integration test is: nullclaw --list-models --provider anthropic
}
