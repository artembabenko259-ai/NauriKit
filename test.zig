const std = @import("std");
pub fn main() !void {
    const io = std.Io.Threaded.global_single_threaded.io();
    const cwd = std.Io.Dir.cwd();
    if (cwd.access(io, "test.zig", .{})) {
        _ = 1;
    } else |_| {}
}
