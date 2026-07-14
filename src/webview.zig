//! WebView — Embedded browser view
//!
//! Wraps the system WebView engine:
//!   Windows → Microsoft WebView2 (Chromium-based)
//!   Linux   → WebKitGTK (WebKit-based)
//!
//! Zero extra bundling — uses what's already on the OS.

const std = @import("std");
const Window = @import("window.zig").Window;
const Ipc = @import("ipc.zig").Ipc;
const platform = @import("lib.zig").platform;
const core_ipc = @import("core_ipc.zig");

pub const WebViewConfig = struct {
    /// Initial URL to navigate to. Mutually exclusive with html.
    url: ?[]const u8 = null,
    /// Inline HTML to load. Mutually exclusive with url.
    html: ?[]const u8 = null,
    /// Additional JS to inject into every page before it loads
    init_script: ?[]const u8 = null,
    /// Whether DevTools are enabled
    dev_tools: bool = false,
    /// Whether to allow navigating to external URLs
    allow_navigation: bool = true,
    /// Background color (RGBA hex string e.g. "#1a1a2e")
    background_color: ?[]const u8 = null,
};

pub const WebView = struct {
    window: *Window,
    config: WebViewConfig,
    handle: platform.WebViewHandle,
    ipc: Ipc,

    const Self = @This();

    pub fn init(self: *Self, window: *Window, config: WebViewConfig) !void {
        self.* = Self{
            .window = window,
            .config = config,
            .handle = undefined,
            .ipc = Ipc.init(window.app.allocator),
        };

        self.handle = try platform.createWebView(window, self, config);

        // Inject the NauriKit JS bridge
        const bridge_js = @embedFile("naurikit.js");
        try platform.webViewAddInitScript(self.handle, bridge_js);

        // Inject user's init script if provided
        if (config.init_script) |script| {
            try platform.webViewAddInitScript(self.handle, script);
        }

        // Load initial content
        if (config.url) |url| {
            try platform.webViewNavigate(self.handle, url);
        } else if (config.html) |html| {
            try platform.webViewLoadHtml(self.handle, html);
        }

        try core_ipc.registerCoreHandlers(self);
    }

    pub fn deinit(self: *Self) void {
        self.ipc.deinit();
        platform.destroyWebView(self.handle);
    }

    // ─── Navigation ───────────────────────────────────────────────────────────

    pub fn navigate(self: *Self, url: []const u8) !void {
        try platform.webViewNavigate(self.handle, url);
    }

    pub fn loadHtml(self: *Self, html: []const u8) !void {
        try platform.webViewLoadHtml(self.handle, html);
    }

    pub fn reload(self: *Self) void {
        platform.webViewReload(self.handle);
    }

    pub fn goBack(self: *Self) void {
        platform.webViewGoBack(self.handle);
    }

    pub fn goForward(self: *Self) void {
        platform.webViewGoForward(self.handle);
    }

    // ─── Script execution ─────────────────────────────────────────────────────

    /// Evaluate JavaScript in the WebView context. Fire-and-forget.
    pub fn eval(self: *Self, script: []const u8) !void {
        try platform.webViewEval(self.handle, script);
    }

    /// Evaluate JS and get the result as a JSON string (async via callback).
    pub fn evalWithResult(
        self: *Self,
        script: []const u8,
        callback: *const fn (result: []const u8) void,
    ) !void {
        try platform.webViewEvalWithResult(self.handle, script, callback);
    }

    // ─── IPC ──────────────────────────────────────────────────────────────────

    /// Register a handler for IPC commands from JavaScript.
    pub fn onCommand(
        self: *Self,
        name: []const u8,
        handler: @import("ipc.zig").CommandHandler,
        user_data: ?*anyopaque,
    ) !void {
        try self.ipc.register(name, handler, user_data);
    }

    /// Called by the platform layer when JS sends an IPC message.
    pub fn handleIpcMessage(self: *Self, payload: []const u8) void {
        self.ipc.dispatch(self, payload);
    }

    // ─── DevTools ─────────────────────────────────────────────────────────────

    pub fn openDevTools(self: *Self) void {
        platform.webViewOpenDevTools(self.handle);
    }
};
