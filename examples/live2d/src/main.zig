const std = @import("std");
const nk = @import("naurikit");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var app = try nk.App.init(allocator, .{
        .name = "Live2D Widget",
        .fs_scope = &.{ "." },
    });
    defer app.deinit();

    const window = try app.createWindow(.{
        .title = "Live2D Widget",
        .width = 400,
        .height = 500,
        .frameless = true,    // No chrome
        .transparent = true,  // Transparent background!
        .resizable = false,
        .always_on_top = true, // Keep widget on top!
    });
    const html_url = "file:///C:/Users/User/Desktop/Nauri/naurikit/examples/live2d/src/index.html";

    const webview = try window.createWebView(.{
        .url = html_url,
        .dev_tools = true,
    });

    // Add a custom IPC command to quit from JS
    try webview.onCommand("quit_widget", nk.IpcCommand.make(quitWidgetHandler), null);

    _ = try app.run();
}

fn quitWidgetHandler(ctx: *nk.IpcContext, _: std.json.Value) void {
    ctx.webview.window.app.quit(0);
    ctx.resolveValue(true);
}
