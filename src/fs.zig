//! fs.zig — Filesystem helpers
//!
//! Thin wrappers around std.fs with convenient error types.

const std = @import("std");

pub const Fs = struct {
    /// Read entire file into an allocated buffer. Caller must free.
    pub fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
        const file = try std.Io.Dir.cwd().openFile(std.Options.debug_io, path, .{});
        defer file.close(std.Options.debug_io);
        const stat = try file.stat(std.Options.debug_io);
        const buf = try allocator.alloc(u8, @intCast(stat.size));
        _ = try file.readPositionalAll(std.Options.debug_io, buf, 0);
        return buf;
    }

    /// Write bytes to a file (creates or truncates).
    pub fn writeFile(path: []const u8, data: []const u8) !void {
        const file = try std.Io.Dir.cwd().createFile(std.Options.debug_io, path, .{ .truncate = true });
        defer file.close(std.Options.debug_io);
        try file.writeStreamingAll(std.Options.debug_io, data);
    }

    /// Append bytes to a file.
    pub fn appendFile(path: []const u8, data: []const u8) !void {
        const file = try std.Io.Dir.cwd().openFile(std.Options.debug_io, path, .{ .mode = .write_only });
        defer file.close(std.Options.debug_io);
        const stat = try file.stat(std.Options.debug_io);
        try file.writePositionalAll(std.Options.debug_io, data, stat.size);
    }

    /// Check if a path exists.
    pub fn exists(path: []const u8) bool {
        std.Io.Dir.cwd().access(std.Options.debug_io, path, .{}) catch return false;
        return true;
    }

    /// Create a directory (including parents).
    pub fn mkdirs(path: []const u8) !void {
        try std.Io.Dir.cwd().makePath(std.Options.debug_io, path);
    }

    /// Delete a file.
    pub fn deleteFile(path: []const u8) !void {
        try std.Io.Dir.cwd().deleteFile(std.Options.debug_io, path);
    }

    /// List directory entries. Returns ArrayList of names (caller frees).
    pub fn listDir(
        allocator: std.mem.Allocator,
        path: []const u8,
    ) !std.ArrayList([]u8) {
        var result = std.ArrayList([]u8).empty;
        var dir = try std.Io.Dir.cwd().openDir(std.Options.debug_io, path, .{ .iterate = true });
        defer dir.close(std.Options.debug_io);

        var iter = dir.iterate();
        while (try iter.next(std.Options.debug_io)) |entry| {
            const name = try allocator.dupe(u8, entry.name);
            try result.append(allocator, name);
        }
        return result;
    }

    /// Get the app data directory (OS-specific).
    pub fn appDataDir(allocator: std.mem.Allocator, app_name: []const u8) ![]u8 {
        const builtin = @import("builtin");
        return switch (builtin.os.tag) {
            .windows => blk: {
                const appdata = std.process.getEnvVarOwned(allocator, "APPDATA") catch
                    return error.NoAppData;
                defer allocator.free(appdata);
                break :blk std.fmt.allocPrint(allocator, "{s}\\{s}", .{ appdata, app_name });
            },
            .linux => blk: {
                const home = std.process.getEnvVarOwned(allocator, "HOME") catch
                    return error.NoHome;
                defer allocator.free(home);
                break :blk std.fmt.allocPrint(allocator, "{s}/.config/{s}", .{ home, app_name });
            },
            else => error.UnsupportedPlatform,
        };
    }
};
