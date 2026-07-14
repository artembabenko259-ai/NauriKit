//! examples/hello/src/main.zig
//!
//! Hello World example for NauriKit.
//! Demonstrates:
//!   - Frameless Window with Mica backdrop
//!   - Type-Safe IPC
//!   - Security Scopes

const std = @import("std");
const nk = @import("naurikit");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // ── Create the application ──────────────────────────────────────────────
    var app = try nk.App.init(allocator, .{
        .name = "NauriKit Hello",
        // Only allow reading/writing files in the temp directory
        .fs_scope = &.{ "C:\\Temp" },
    });
    defer app.deinit();

    // ── Create a window ─────────────────────────────────────────────────────
    const window = try app.createWindow(.{
        .title = "NauriKit — Hello World",
        .width = 900,
        .height = 640,
        .center = true,
        .theme = .dark,
        .frameless = true,
        .transparent = true,
        .backdrop = .mica, // Enable Windows 11 Mica blur
    });

    // ── Attach a WebView ────────────────────────────────────────────────────
    const webview = try window.createWebView(.{
        .html = @embedFile("index.html"),
        .dev_tools = true,
    });

    // ── Register Custom IPC handlers ────────────────────────────────────────

    // "greet" command uses the new Type-Safe IPC!
    try webview.onCommand("greet", nk.IpcCommand.makeTyped(GreetArgs, greetHandler), null);
    try webview.onCommand("slow_task", nk.IpcCommand.make(slowTaskHandler), null);

    // "get_os_info" command takes no arguments (void)
    try webview.onCommand("get_os_info", nk.IpcCommand.makeTyped(void, osInfoHandler), null);

    // Note: fs_read, fs_write, app_quit, and window_* are automatically 
    // registered by NauriKit core!

    // ── Show the window and run ─────────────────────────────────────────────
    window.show();
    const exit_code = try app.run();
    std.process.exit(@intCast(exit_code));
}

// ─── Handlers ─────────────────────────────────────────────────────────────────

const GreetArgs = struct {
    name: []const u8,
};

fn greetHandler(ctx: *nk.IpcContext, args: GreetArgs) void {
    var buf: [256]u8 = undefined;
    const greeting = std.fmt.bufPrint(
        &buf,
        "Hello, {s}! 👋 Built with NauriKit + Zig 0.16",
        .{args.name},
    ) catch "Hello, World!";

    ctx.resolveValue(greeting);
}

fn slowTaskHandler(ctx: *nk.IpcContext, _: std.json.Value) void {
    // Simulate a very heavy operation (e.g. database query, hashing, large file read)
    var i: u64 = 0;
    while (i < 500_000_000) : (i += 1) {
        std.mem.doNotOptimizeAway(i);
    }
    ctx.resolveValue("Heavy task completed successfully! The UI didn't freeze, did it?");
}

fn osInfoHandler(ctx: *nk.IpcContext, _: void) void {
    const builtin = @import("builtin");
    ctx.resolveValue(.{
        .os = @tagName(builtin.os.tag),
        .arch = @tagName(builtin.cpu.arch),
        .framework = "NauriKit",
        .version = nk.version.string,
        .zig_version = @import("builtin").zig_version_string,
        .features = .{ "Mica", "Type-Safe IPC", "Scopes" },
    });
}
