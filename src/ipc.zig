//! IPC — Inter-Process Communication between JS and Zig
//!
//! Zig 0.16 compatible version.
//! ArrayList API updated to pass allocator per call.

const std = @import("std");

pub const IpcMessage = struct {
    id: []const u8,
    cmd: []const u8,
    payload: std.json.Value,
};

pub const IpcContext = struct {
    resolve: *const fn (ctx: *IpcContext, result_json: []const u8) void,
    reject: *const fn (ctx: *IpcContext, err_msg: []const u8) void,
    id: []const u8,
    webview: *@import("webview.zig").WebView,
    user_data: ?*anyopaque,
    _allocator: std.mem.Allocator,
    _response_buf: [8192]u8,

    pub fn resolveValue(self: *IpcContext, value: anytype) void {
        var buf: [65536]u8 = undefined;
        var stream = std.Io.Writer.fixed(&buf);
        std.json.Stringify.value(value, .{}, &stream) catch {
            self.reject(self, "serialization error");
            return;
        };
        self.resolve(self, buf[0..stream.end]);
    }

    pub fn rejectError(self: *IpcContext, comptime fmt: []const u8, args: anytype) void {
        var buf: [1024]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, fmt, args) catch "error";
        self.reject(self, msg);
    }
};

pub const CommandHandler = *const fn (ctx: *IpcContext, payload: std.json.Value) void;

const CommandEntry = struct {
    name: []const u8,
    handler: CommandHandler,
    user_data: ?*anyopaque,
};

pub const Ipc = struct {
    allocator: std.mem.Allocator,
    commands: std.ArrayList(CommandEntry),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .commands = std.ArrayList(CommandEntry).empty,
        };
    }

    pub fn deinit(self: *Self) void {
        self.commands.deinit(self.allocator);
    }

    pub fn register(
        self: *Self,
        name: []const u8,
        handler: CommandHandler,
        user_data: ?*anyopaque,
    ) !void {
        try self.commands.append(self.allocator, .{
            .name = name,
            .handler = handler,
            .user_data = user_data,
        });
    }

    const DispatchArgs = struct {
        ipc: *Ipc,
        webview: *@import("webview.zig").WebView,
        raw: []const u8,
    };

    fn dispatchWorker(args: DispatchArgs) void {
        var arena = std.heap.ArenaAllocator.init(args.ipc.allocator);
        defer arena.deinit();
        const alloc = arena.allocator();

        defer args.ipc.allocator.free(args.raw); // Free the raw string allocated in dispatch()

        const parsed = std.json.parseFromSlice(
            std.json.Value,
            alloc,
            args.raw,
            .{},
        ) catch |err| {
            std.log.err("IPC: failed to parse JSON: {}", .{err});
            return;
        };
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) return;

        const obj = root.object;
        const id_val = obj.get("id") orelse return;
        const cmd_val = obj.get("cmd") orelse return;
        const payload_val = obj.get("payload") orelse std.json.Value{ .null = {} };

        if (id_val != .string or cmd_val != .string) return;

        const id = id_val.string;
        const cmd = cmd_val.string;

        for (args.ipc.commands.items) |entry| {
            if (std.mem.eql(u8, entry.name, cmd)) {
                var ctx = IpcContext{
                    .id = id,
                    .webview = args.webview,
                    .user_data = entry.user_data,
                    ._allocator = alloc,
                    ._response_buf = undefined,
                    .resolve = ipcResolve,
                    .reject = ipcReject,
                };
                entry.handler(&ctx, payload_val);
                return;
            }
        }

        std.log.warn("IPC: unknown command '{s}'", .{cmd});
        sendReject(args.webview, id, "unknown command") catch {};
    }

    pub fn dispatch(
        self: *Self,
        webview: *@import("webview.zig").WebView,
        raw: []const u8,
    ) void {
        const raw_copy = self.allocator.dupe(u8, raw) catch return;
        
        const args = DispatchArgs{
            .ipc = self,
            .webview = webview,
            .raw = raw_copy,
        };
        
        const th = std.Thread.spawn(.{}, dispatchWorker, .{args}) catch |err| {
            std.log.err("IPC: failed to spawn thread: {}", .{err});
            self.allocator.free(raw_copy);
            return;
        };
        th.detach();
    }
};

fn ipcResolve(ctx: *IpcContext, result_json: []const u8) void {
    sendResolve(ctx.webview, ctx.id, result_json) catch |err| {
        std.log.err("IPC resolve failed: {}", .{err});
    };
}

fn ipcReject(ctx: *IpcContext, err_msg: []const u8) void {
    sendReject(ctx.webview, ctx.id, err_msg) catch |err| {
        std.log.err("IPC reject failed: {}", .{err});
    };
}

const platform = @import("platform/windows.zig");

fn sendResolve(webview: *@import("webview.zig").WebView, id: []const u8, result: []const u8) !void {
    var buf: [65536]u8 = undefined;
    const script = try std.fmt.bufPrint(
        &buf,
        "window.__naurikit.__resolve('{s}', {s})",
        .{ id, result },
    );
    platform.postIpcResponse(webview.window.handle, script);
}

fn sendReject(webview: *@import("webview.zig").WebView, id: []const u8, msg: []const u8) !void {
    var buf: [65536]u8 = undefined;
    const script = try std.fmt.bufPrint(
        &buf,
        "window.__naurikit.__reject('{s}', '{s}')",
        .{ id, msg },
    );
    platform.postIpcResponse(webview.window.handle, script);
}

const JsonStringFormatter = struct {
    s: []const u8,
    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.writeByte('"');
        for (self.s) |c| {
            switch (c) {
                '"' => try writer.writeAll("\\\""),
                '\\' => try writer.writeAll("\\\\"),
                '\n' => try writer.writeAll("\\n"),
                '\r' => try writer.writeAll("\\r"),
                '\t' => try writer.writeAll("\\t"),
                else => try writer.writeByte(c),
            }
        }
        try writer.writeByte('"');
    }
};

fn fmtJsonString(s: []const u8) JsonStringFormatter {
    return .{ .s = s };
}

pub const IpcCommand = struct {
    pub fn make(comptime handler: anytype) CommandHandler {
        return struct {
            fn h(ctx: *IpcContext, payload: std.json.Value) void {
                handler(ctx, payload);
            }
        }.h;
    }

    pub fn makeTyped(comptime ArgsType: type, comptime handler: anytype) CommandHandler {
        return struct {
            fn h(ctx: *IpcContext, payload: std.json.Value) void {
                if (ArgsType == void) {
                    handler(ctx, {});
                    return;
                }
                const parsed = std.json.parseFromValue(ArgsType, ctx._allocator, payload, .{ .ignore_unknown_fields = true }) catch |err| {
                    ctx.rejectError("invalid arguments: {s}", .{@errorName(err)});
                    return;
                };
                defer parsed.deinit();
                handler(ctx, parsed.value);
            }
        }.h;
    }
};
