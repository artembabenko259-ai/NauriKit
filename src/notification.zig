//! notification.zig — System tray notifications

const std = @import("std");
const platform = @import("lib.zig").platform;

pub const Notification = struct {
    title: []const u8,
    body: []const u8,
    icon: ?[]const u8 = null,

    pub fn show(self: Notification) void {
        platform.showNotification(self.title, self.body, self.icon);
    }

    /// Builder-style helper
    pub fn builder(title: []const u8) Notification {
        return .{ .title = title, .body = "" };
    }

    pub fn withBody(self: Notification, body: []const u8) Notification {
        var n = self;
        n.body = body;
        return n;
    }

    pub fn withIcon(self: Notification, icon: []const u8) Notification {
        var n = self;
        n.icon = icon;
        return n;
    }
};
