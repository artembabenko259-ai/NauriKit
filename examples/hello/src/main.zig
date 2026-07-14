//! examples/hello/src/main.zig
//!
//! Hello World example for NauriKit.
//! Demonstrates:
//!   - Creating an App and Window
//!   - Embedding a WebView with inline HTML
//!   - Registering IPC command handlers
//!   - Responding to JS calls from Zig

const std = @import("std");
const nk = @import("naurikit");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // ── Create the application ──────────────────────────────────────────────
    var app = try nk.App.init(allocator, .{
        .name = "NauriKit Hello",
    });
    defer app.deinit();

    // ── Create a window ─────────────────────────────────────────────────────
    const window = try app.createWindow(.{
        .title = "NauriKit — Hello World",
        .width = 900,
        .height = 640,
        .center = true,
        .theme = .dark,
    });

    // ── Attach a WebView ────────────────────────────────────────────────────
    const webview = try window.createWebView(.{
        .html = @embedFile("index.html"),
        .dev_tools = true,
    });

    // ── Register IPC handlers ────────────────────────────────────────────────

    // "greet" command — receives a name, returns a greeting string
    try webview.onCommand("greet", nk.IpcCommand.make(greetHandler), null);

    // "get_os_info" command — returns OS information
    try webview.onCommand("get_os_info", nk.IpcCommand.make(osInfoHandler), null);

    // "fs_read" command — reads a file
    try webview.onCommand("fs_read", nk.IpcCommand.make(fsReadHandler), null);

    // "fs_write" command — writes a file
    try webview.onCommand("fs_write", nk.IpcCommand.make(fsWriteHandler), null);

    // "app_quit" command
    try webview.onCommand("app_quit", nk.IpcCommand.make(struct {
        fn h(ctx: *nk.IpcContext, _: std.json.Value) void {
            ctx.webview.window.app.quit(0);
            ctx.resolveValue(true);
        }
    }.h), null);

    // "window_minimize"
    try webview.onCommand("window_minimize", nk.IpcCommand.make(struct {
        fn h(ctx: *nk.IpcContext, _: std.json.Value) void {
            ctx.webview.window.minimize();
            ctx.resolveValue(true);
        }
    }.h), null);

    // "window_maximize"
    try webview.onCommand("window_maximize", nk.IpcCommand.make(struct {
        fn h(ctx: *nk.IpcContext, _: std.json.Value) void {
            ctx.webview.window.maximize();
            ctx.resolveValue(true);
        }
    }.h), null);

    // ── Show the window and run ─────────────────────────────────────────────
    window.show();
    const exit_code = try app.run();
    std.process.exit(@intCast(exit_code));
}

// ─── Handlers ─────────────────────────────────────────────────────────────────

fn greetHandler(ctx: *nk.IpcContext, payload: std.json.Value) void {
    const name = if (payload == .object)
        (payload.object.get("name") orelse std.json.Value{ .string = "World" }).string
    else
        "World";

    var buf: [256]u8 = undefined;
    const greeting = std.fmt.bufPrint(
        &buf,
        "Hello, {s}! 👋 Built with NauriKit + Zig",
        .{name},
    ) catch "Hello, World!";

    ctx.resolveValue(greeting);
}

fn osInfoHandler(ctx: *nk.IpcContext, _: std.json.Value) void {
    const builtin = @import("builtin");
    ctx.resolveValue(.{
        .os = @tagName(builtin.os.tag),
        .arch = @tagName(builtin.cpu.arch),
        .framework = "NauriKit",
        .version = nk.version.string,
        .zig_version = @import("builtin").zig_version_string,
    });
}

fn fsReadHandler(ctx: *nk.IpcContext, payload: std.json.Value) void {
    const path = if (payload == .object)
        (payload.object.get("path") orelse return ctx.rejectError("missing 'path'", .{})).string
    else
        return ctx.rejectError("invalid payload", .{});

    const data = nk.Fs.readFile(ctx._allocator, path) catch |err| {
        return ctx.rejectError("read error: {}", .{err});
    };
    ctx.resolveValue(data);
}

fn fsWriteHandler(ctx: *nk.IpcContext, payload: std.json.Value) void {
    if (payload != .object) return ctx.rejectError("invalid payload", .{});
    const obj = payload.object;

    const path = (obj.get("path") orelse return ctx.rejectError("missing 'path'", .{})).string;
    const contents = (obj.get("contents") orelse return ctx.rejectError("missing 'contents'", .{})).string;

    nk.Fs.writeFile(path, contents) catch |err| {
        return ctx.rejectError("write error: {}", .{err});
    };
    ctx.resolveValue(true);
}
