//! Window — Native OS window wrapper
//!
//! Abstracts Win32 HWND / GTK GtkWindow behind a unified interface.

const std = @import("std");
const App = @import("app.zig").App;
const WebView = @import("webview.zig").WebView;
const WebViewConfig = @import("webview.zig").WebViewConfig;
const platform = @import("lib.zig").platform;

pub const WindowTheme = enum { system, light, dark };

pub const WindowBackdrop = enum { none, mica, acrylic };

pub const WindowOptions = struct {
    title: []const u8 = "NauriKit App",
    width: u32 = 800,
    height: u32 = 600,
    frameless: bool = false,
    min_width: u32 = 320,
    min_height: u32 = 240,
    resizable: bool = true,
    decorations: bool = true,
    transparent: bool = false,
    backdrop: WindowBackdrop = .none,
    always_on_top: bool = false,
    center: bool = true,
    theme: WindowTheme = .system,
    /// If true, starts hidden (call show() manually)
    hidden: bool = false,
};

pub const Window = struct {
    app: *App,
    config: WindowOptions,
    handle: platform.WindowHandle,
    webview: ?*WebView,

    const Self = @This();

    pub fn init(app: *App, config: WindowOptions) !Self {
        const handle = try platform.createWindow(app, config);
        return Self{
            .app = app,
            .config = config,
            .handle = handle,
            .webview = null,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.webview) |wv| {
            wv.deinit();
            self.app.allocator.destroy(wv);
        }
        platform.destroyWindow(self.handle);
    }

    // ─── Visibility ───────────────────────────────────────────────────────────

    pub fn show(self: *Self) void {
        platform.showWindow(self.handle);
    }

    pub fn hide(self: *Self) void {
        platform.hideWindow(self.handle);
    }

    pub fn focus(self: *Self) void {
        platform.focusWindow(self.handle);
    }

    // ─── Properties ───────────────────────────────────────────────────────────

    pub fn setTitle(self: *Self, title: []const u8) void {
        platform.setWindowTitle(self.handle, title);
    }

    pub fn setSize(self: *Self, width: u32, height: u32) void {
        platform.setWindowSize(self.handle, width, height);
    }

    pub fn setMinSize(self: *Self, width: u32, height: u32) void {
        platform.setWindowMinSize(self.handle, width, height);
    }

    pub fn center(self: *Self) void {
        platform.centerWindow(self.handle);
    }

    pub fn setAlwaysOnTop(self: *Self, enable: bool) void {
        platform.setWindowAlwaysOnTop(self.handle, enable);
    }

    pub fn setTheme(self: *Self, theme: WindowTheme) void {
        platform.setWindowTheme(self.handle, theme);
    }

    pub fn maximize(self: *Self) void {
        platform.maximizeWindow(self.handle);
    }

    pub fn minimize(self: *Self) void {
        platform.minimizeWindow(self.handle);
    }

    pub fn restore(self: *Self) void {
        platform.windowRestore(self.handle);
    }

    pub fn close(self: *Self) void {
        platform.windowClose(self.handle);
    }

    pub fn startDrag(self: *Self) void {
        platform.windowStartDrag(self.handle);
    }

    pub fn startResize(self: *Self, edge: u32) void {
        platform.windowStartResize(self.handle, edge);
    }

    // ─── WebView ──────────────────────────────────────────────────────────────

    /// Attach a WebView to this window.
    pub fn createWebView(self: *Self, config: WebViewConfig) !*WebView {
        const wv = try self.app.allocator.create(WebView);
        try wv.init(self, config);
        self.webview = wv;
        return wv;
    }
};
