const std = @import("std");
const nk = @import("lib.zig");
const c = @cImport({
    @cInclude("stdio.h");
});

extern "user32" fn MessageBoxA(hWnd: ?*anyopaque, lpText: [*:0]const u8, lpCaption: [*:0]const u8, uType: u32) callconv(.winapi) i32;

pub fn registerCoreHandlers(wv: *nk.WebView) !void {
    try wv.onCommand("fs_read", nk.IpcCommand.makeTyped(FsReadArgs, fsReadHandler), null);
    try wv.onCommand("fs_write", nk.IpcCommand.makeTyped(FsWriteArgs, fsWriteHandler), null);
    try wv.onCommand("window_minimize", nk.IpcCommand.make(windowMinimizeHandler), null);
    try wv.onCommand("window_maximize", nk.IpcCommand.make(windowMaximizeHandler), null);
    try wv.onCommand("window_set_title", nk.IpcCommand.make(windowSetTitleHandler), null);
    try wv.onCommand("window_start_drag", nk.IpcCommand.make(windowStartDragHandler), null);
    try wv.onCommand("window_start_resize", nk.IpcCommand.makeTyped(WindowStartResizeArgs, windowStartResizeHandler), null);
    try wv.onCommand("dialog_message", nk.IpcCommand.make(dialogMessageHandler), null);
    try wv.onCommand("dialog_open_file", nk.IpcCommand.makeTyped(DialogOpenFileArgs, dialogOpenFileHandler), null);
    try wv.onCommand("dialog_save_file", nk.IpcCommand.makeTyped(DialogSaveFileArgs, dialogSaveFileHandler), null);
    try wv.onCommand("app_quit", nk.IpcCommand.make(appQuitHandler), null);
}

const FsReadArgs = struct {
    path: []const u8,
};

fn fsReadHandler(ctx: *nk.IpcContext, args: FsReadArgs) void {
    const scope = ctx.webview.window.app.config.fs_scope;
    const allowed = nk.Fs.checkScope(ctx._allocator, scope, args.path) catch false;
    if (!allowed) {
        ctx.rejectError("Access denied by scope: {s}", .{args.path});
        return;
    }

    const data = nk.Fs.readFile(ctx._allocator, args.path) catch |err| {
        ctx.rejectError("read error: {s}", .{@errorName(err)});
        return;
    };
    ctx.resolveValue(data);
}

const FsWriteArgs = struct {
    path: []const u8,
    contents: []const u8,
};

fn fsWriteHandler(ctx: *nk.IpcContext, args: FsWriteArgs) void {
    const scope = ctx.webview.window.app.config.fs_scope;
    const allowed = nk.Fs.checkScope(ctx._allocator, scope, args.path) catch false;
    if (!allowed) {
        ctx.rejectError("Access denied by scope: {s}", .{args.path});
        return;
    }

    nk.Fs.writeFile(args.path, args.contents) catch |err| {
        ctx.rejectError("write error: {s}", .{@errorName(err)});
        return;
    };
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

const WindowStartResizeArgs = struct {
    edge: u32,
};

fn windowStartResizeHandler(ctx: *nk.IpcContext, args: WindowStartResizeArgs) void {
    ctx.webview.window.startResize(args.edge);
    ctx.resolveValue(true);
}

fn appQuitHandler(ctx: *nk.IpcContext, payload: std.json.Value) void {
    var code: i32 = 0;
    if (payload == .object and payload.object.contains("code")) {
        const code_val = payload.object.get("code").?;
        if (code_val == .integer) {
            code = @intCast(code_val.integer);
        }
    }
    ctx.webview.window.app.quit(code);
    ctx.resolveValue(true);
}

fn dialogMessageHandler(ctx: *nk.IpcContext, payload: std.json.Value) void {
    if (payload != .object or !payload.object.contains("text")) {
        ctx.rejectError("{s}", .{"Missing 'text'"});
        return;
    }
    const text = payload.object.get("text").?.string;
    const title = if (payload.object.contains("title")) payload.object.get("title").?.string else "NauriKit";
    
    // Default to info if not specified
    const res = nk.Dialog.message(title, text, .info);
    ctx.resolveValue(@tagName(res));
}

const DialogOpenFileArgs = struct {
    title: ?[]const u8 = null,
    filters: ?[]const nk.FileFilter = null,
};

fn dialogOpenFileHandler(ctx: *nk.IpcContext, args: DialogOpenFileArgs) void {
    const filters = args.filters orelse &[_]nk.FileFilter{};
    const title = args.title orelse "Open File";
    
    if (nk.Dialog.openFile(ctx._allocator, title, filters)) |opt_path| {
        if (opt_path) |path| {
            ctx.resolveValue(path);
        } else {
            ctx.resolveValue(std.json.Value{ .null = {} }); // Cancelled
        }
    } else |err| {
        ctx.rejectError("dialog error: {s}", .{@errorName(err)});
    }
}

const DialogSaveFileArgs = struct {
    title: ?[]const u8 = null,
    filters: ?[]const nk.FileFilter = null,
};

fn dialogSaveFileHandler(ctx: *nk.IpcContext, args: DialogSaveFileArgs) void {
    const filters = args.filters orelse &[_]nk.FileFilter{};
    const title = args.title orelse "Save File";
    
    if (nk.Dialog.saveFile(ctx._allocator, title, filters)) |opt_path| {
        if (opt_path) |path| {
            ctx.resolveValue(path);
        } else {
            ctx.resolveValue(std.json.Value{ .null = {} }); // Cancelled
        }
    } else |err| {
        ctx.rejectError("dialog error: {s}", .{@errorName(err)});
    }
}
