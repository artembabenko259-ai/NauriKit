//! platform/linux.zig — GTK + WebKitGTK backend (Phase 5 — stub)
//!
//! This will be implemented in Phase 5.
//! Currently provides compile-time stubs so the codebase builds.

const std = @import("std");

pub const WindowHandle = *anyopaque;
pub const WebViewHandle = *anyopaque;

pub fn initCOM() !void {}
pub fn uninitCOM() void {}

pub fn runEventLoop(_: *@import("../app.zig").App) !void {
    @compileError("Linux backend not yet implemented — coming in Phase 5");
}

pub fn postQuitMessage(_: i32) void {}

pub fn createWindow(
    _: *@import("../app.zig").App,
    _: @import("../window.zig").WindowConfig,
) !WindowHandle {
    @compileError("Linux backend not yet implemented");
}

pub fn destroyWindow(_: WindowHandle) void {}
pub fn showWindow(_: WindowHandle) void {}
pub fn hideWindow(_: WindowHandle) void {}
pub fn focusWindow(_: WindowHandle) void {}
pub fn maximizeWindow(_: WindowHandle) void {}
pub fn minimizeWindow(_: WindowHandle) void {}
pub fn restoreWindow(_: WindowHandle) void {}
pub fn setWindowTitle(_: WindowHandle, _: []const u8) void {}
pub fn setWindowSize(_: WindowHandle, _: u32, _: u32) void {}
pub fn setWindowMinSize(_: WindowHandle, _: u32, _: u32) void {}
pub fn centerWindow(_: WindowHandle) void {}
pub fn setWindowAlwaysOnTop(_: WindowHandle, _: bool) void {}
pub fn setWindowTheme(_: WindowHandle, _: @import("../window.zig").WindowTheme) void {}

pub fn createWebView(
    _: *@import("../window.zig").Window,
    _: *@import("../webview.zig").WebView,
    _: @import("../webview.zig").WebViewConfig,
) !WebViewHandle {
    @compileError("Linux backend not yet implemented");
}

pub fn destroyWebView(_: WebViewHandle) void {}
pub fn webView2Pump(_: WebViewHandle) void {}
pub fn webView2Resize(_: WebViewHandle, _: u32, _: u32) void {}
pub fn webViewNavigate(_: WebViewHandle, _: []const u8) !void {}
pub fn webViewLoadHtml(_: WebViewHandle, _: []const u8) !void {}
pub fn webViewAddInitScript(_: WebViewHandle, _: []const u8) !void {}
pub fn webViewEval(_: WebViewHandle, _: []const u8) !void {}
pub fn webViewEvalWithResult(_: WebViewHandle, _: []const u8, _: *const fn ([]const u8) void) !void {}
pub fn webViewReload(_: WebViewHandle) void {}
pub fn webViewGoBack(_: WebViewHandle) void {}
pub fn webViewGoForward(_: WebViewHandle) void {}
pub fn webViewOpenDevTools(_: WebViewHandle) void {}
