const std = @import("std");
const nk = @import("naurikit");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try nk.App.init(allocator, .{
        .name = "Nauri React App",
    });
    defer app.deinit();

    const window = try app.createWindow(.{
        .title = "NauriKit + React + TypeScript",
        .width = 1024,
        .height = 768,
        .frameless = true,
        .center = true,
        .theme = .system,
    });

    const webview = try window.createWebView(.{
        .url = "http://localhost:5173", // Point to Vite dev server
        .dev_tools = true,
    });

    // Register a test IPC command
    try webview.onCommand("ping", nk.IpcCommand.make(struct {
        fn h(ctx: *nk.IpcContext, _: std.json.Value) void {
            ctx.resolveValue("pong from Zig!");
        }
    }.h), null);

    window.show();
    const exit_code = try app.run();
    std.process.exit(@intCast(exit_code));
}
