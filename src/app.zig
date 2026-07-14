//! App — Application lifecycle manager
//!
//! Zig 0.16 compatible version.
//! ArrayList API changed: no more .init(alloc), now takes allocator per-call.

const std = @import("std");
const builtin = @import("builtin");
const Window = @import("window.zig").Window;
const WindowOptions = @import("window.zig").WindowOptions;
const platform = @import("lib.zig").platform;

pub const AppConfig = struct {
    /// Application name shown in taskbar/title
    name: []const u8 = "NauriKit App",
    /// Optional application icon path (.ico on Windows)
    icon_path: ?[]const u8 = null,
    /// Whether to show a tray icon
    tray: bool = false,
    /// Whether to allow multiple instances
    single_instance: bool = false,
    /// Allowed filesystem paths for IPC. If null, all paths are allowed (insecure).
    /// If an empty slice `&.{}`, no paths are allowed.
    fs_scope: ?[]const []const u8 = null,
};

pub const App = struct {
    allocator: std.mem.Allocator,
    config: AppConfig,
    windows: std.ArrayList(*Window),
    running: bool,
    exit_code: i32,

    const Self = @This();

    /// Initialize the application. Must be called once.
    pub fn init(allocator: std.mem.Allocator, config: AppConfig) !Self {
        try platform.initCOM();

        return Self{
            .allocator = allocator,
            .config = config,
            .windows = std.ArrayList(*Window).empty,
            .running = false,
            .exit_code = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.windows.items) |w| {
            w.deinit();
            self.allocator.destroy(w);
        }
        self.windows.deinit(self.allocator);
        platform.uninitCOM();
    }

    /// Create a new window owned by this app.
    pub fn createWindow(self: *Self, config: WindowOptions) !*Window {
        const w = try self.allocator.create(Window);
        w.* = try Window.init(self, config);
        try self.windows.append(self.allocator, w);
        return w;
    }

    /// Run the event loop. Blocks until all windows are closed.
    pub fn run(self: *Self) !i32 {
        self.running = true;
        defer self.running = false;

        try platform.runEventLoop(self);
        return self.exit_code;
    }

    /// Request graceful shutdown.
    pub fn quit(self: *Self, code: i32) void {
        self.exit_code = code;
        for (self.windows.items) |w| {
            w.close();
        }
    }

    /// Remove a window from the managed list (called on window close).
    pub fn removeWindow(self: *Self, window: *Window) void {
        for (self.windows.items, 0..) |w, i| {
            if (w == window) {
                _ = self.windows.swapRemove(i);
                break;
            }
        }
        // Quit when last window is closed
        if (self.windows.items.len == 0) {
            self.quit(0);
        }
    }
};
