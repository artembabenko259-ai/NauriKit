const std = @import("std");
fn worker(x: i32) void {
    std.debug.print("worker: {}\n", .{x});
}
pub fn main() !void {
    const th = try std.Thread.spawn(.{}, worker, .{42});
    th.join();
}
