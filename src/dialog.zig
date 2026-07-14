//! dialog.zig — Native OS dialogs

const std = @import("std");
const platform = @import("lib.zig").platform;

pub const FileFilter = struct {
    name: []const u8,
    pattern: []const u8, // e.g. "*.txt;*.md"
};

pub const Dialog = struct {
    /// Open a file picker. Returns selected path (caller must free) or null.
    pub fn openFile(
        allocator: std.mem.Allocator,
        title: []const u8,
        filters: []const FileFilter,
    ) !?[]u8 {
        return platform.dialogOpenFile(allocator, title, filters);
    }

    /// Open a folder picker. Returns selected path or null.
    pub fn openFolder(
        allocator: std.mem.Allocator,
        title: []const u8,
    ) !?[]u8 {
        return platform.dialogOpenFolder(allocator, title);
    }

    /// Save file dialog. Returns chosen path or null.
    pub fn saveFile(
        allocator: std.mem.Allocator,
        title: []const u8,
        filters: []const FileFilter,
    ) !?[]u8 {
        return platform.dialogSaveFile(allocator, title, filters);
    }

    pub const MessageKind = enum { info, warning, @"error", question };
    pub const MessageResult = enum { ok, cancel, yes, no };

    /// Show a message box. Returns which button was pressed.
    pub fn message(
        title: []const u8,
        text: []const u8,
        kind: MessageKind,
    ) MessageResult {
        return platform.dialogMessage(title, text, kind);
    }
};
