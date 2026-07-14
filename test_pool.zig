const std = @import("std");
pub fn main() !void {
    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = std.heap.page_allocator });
    pool.deinit();
}
