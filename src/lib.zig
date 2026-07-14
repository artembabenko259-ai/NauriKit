//! NauriKit — Ultra-lightweight desktop app framework
//! Built with Zig for maximum performance and minimal binary size.
//!
//! Public API surface:
//!   - App         → application lifecycle
//!   - Window      → native window management
//!   - WebView     → embedded browser view
//!   - Ipc         → JavaScript ↔ Native communication
//!   - Dialog      → native OS dialogs
//!   - Fs          → filesystem helpers
//!   - Notification→ system tray notifications

const builtin = @import("builtin");

pub const App = @import("app.zig").App;
pub const AppConfig = @import("app.zig").AppConfig;
pub const Window = @import("window.zig").Window;
pub const WindowConfig = @import("window.zig").WindowConfig;
pub const WebView = @import("webview.zig").WebView;
pub const WebViewConfig = @import("webview.zig").WebViewConfig;
pub const Ipc = @import("ipc.zig").Ipc;
pub const IpcCommand = @import("ipc.zig").IpcCommand;
pub const IpcContext = @import("ipc.zig").IpcContext;
pub const Dialog = @import("dialog.zig").Dialog;
pub const Fs = @import("fs.zig").Fs;
pub const Notification = @import("notification.zig").Notification;

// Platform-specific internals (not part of public API)
pub const platform = switch (builtin.os.tag) {
    .windows => @import("platform/windows.zig"),
    .linux => @import("platform/linux.zig"),
    else => @compileError("NauriKit: unsupported platform"),
};

// Version info
pub const version = struct {
    pub const major = 0;
    pub const minor = 1;
    pub const patch = 0;
    pub const string = "0.1.0";
};

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
