const std = @import("std");
const nk = @import("lib.zig");
const c = @cImport({
    @cInclude("stdio.h");
});

extern "user32" fn MessageBoxA(hWnd: ?*anyopaque, lpText: [*:0]const u8, lpCaption: [*:0]const u8, uType: u32) callconv(.winapi) i32;

pub fn registerCoreHandlers(wv: *nk.WebView) !void {
    try wv.onCommand("fs_read", nk.IpcCommand.make(fsReadHandler), null);
    try wv.onCommand("fs_write", nk.IpcCommand.make(fsWriteHandler), null);
    try wv.onCommand("window_minimize", nk.IpcCommand.make(windowMinimizeHandler), null);
    try wv.onCommand("window_maximize", nk.IpcCommand.make(windowMaximizeHandler), null);
    try wv.onCommand("window_set_title", nk.IpcCommand.make(windowSetTitleHandler), null);
    try wv.onCommand("window_start_drag", nk.IpcCommand.make(windowStartDragHandler), null);
    try wv.onCommand("dialog_message", nk.IpcCommand.make(dialogMessageHandler), null);
}

fn fsReadHandler(ctx: *nk.IpcContext, payload: std.json.Value) void {
    if (payload != .object or !payload.object.contains("path")) {
        ctx.rejectError("{s}", .{"Missing 'path' argument"});
        return;
    }
    const path = payload.object.get("path").?.string;
    
    const path_z = ctx.webview.window.app.allocator.dupeZ(u8, path) catch return;
    defer ctx.webview.window.app.allocator.free(path_z);
    
    const file = c.fopen(path_z.ptr, "rb") orelse {
        ctx.rejectError("{s}", .{"Cannot open file"});
        return;
    };
    defer _ = c.fclose(file);
    
    _ = c.fseek(file, 0, c.SEEK_END);
    const size = c.ftell(file);
    _ = c.fseek(file, 0, c.SEEK_SET);
    
    const content = ctx.webview.window.app.allocator.alloc(u8, @intCast(size)) catch return;
    defer ctx.webview.window.app.allocator.free(content);
    
    _ = c.fread(content.ptr, 1, @intCast(size), file);
    
    ctx.resolveValue(content);
}

fn fsWriteHandler(ctx: *nk.IpcContext, payload: std.json.Value) void {
    if (payload != .object or !payload.object.contains("path") or !payload.object.contains("contents")) {
        ctx.rejectError("{s}", .{"Missing 'path' or 'contents'"});
        return;
    }
    const path = payload.object.get("path").?.string;
    const contents = payload.object.get("contents").?.string;
    
    const path_z = ctx.webview.window.app.allocator.dupeZ(u8, path) catch return;
    defer ctx.webview.window.app.allocator.free(path_z);

    const file = c.fopen(path_z.ptr, "wb") orelse {
        ctx.rejectError("{s}", .{"Cannot create file"});
        return;
    };
    defer _ = c.fclose(file);
    
    _ = c.fwrite(contents.ptr, 1, contents.len, file);
    
    ctx.resolveValue(true);
}

fn windowMinimizeHandler(ctx: *nk.IpcContext, _: std.json.Value) void {
    ctx.webview.window.minimize();
    ctx.resolveValue(true);
}

fn windowMaximizeHandler(ctx: *nk.IpcContext, _: std.json.Value) void {
    ctx.webview.window.maximize();
    ctx.resolveValue(true);
}

fn windowSetTitleHandler(ctx: *nk.IpcContext, payload: std.json.Value) void {
    if (payload == .object and payload.object.contains("title")) {
        const title = payload.object.get("title").?.string;
        ctx.webview.window.setTitle(title);
    }
    ctx.resolveValue(true);
}

fn windowStartDragHandler(ctx: *nk.IpcContext, _: std.json.Value) void {
    ctx.webview.window.startDrag();
    ctx.resolveValue(true);
}

fn dialogMessageHandler(ctx: *nk.IpcContext, payload: std.json.Value) void {
    if (payload != .object or !payload.object.contains("text")) {
        ctx.rejectError("{s}", .{"Missing 'text'"});
        return;
    }
    const text = payload.object.get("text").?.string;
    const title = if (payload.object.contains("title")) payload.object.get("title").?.string else "NauriKit";
    
    const text_z = ctx.webview.window.app.allocator.dupeZ(u8, text) catch return;
    defer ctx.webview.window.app.allocator.free(text_z);
    
    const title_z = ctx.webview.window.app.allocator.dupeZ(u8, title) catch return;
    defer ctx.webview.window.app.allocator.free(title_z);
    
    _ = MessageBoxA(null, text_z.ptr, title_z.ptr, 0);
    ctx.resolveValue(true);
}
