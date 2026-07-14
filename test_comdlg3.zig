const std = @import("std");

const HWND = std.os.windows.HWND;
const HINSTANCE = std.os.windows.HINSTANCE;
const LPARAM = std.os.windows.LPARAM;

pub const OPENFILENAMEW = extern struct {
    lStructSize: u32,
    hwndOwner: ?HWND,
    hInstance: ?HINSTANCE,
    lpstrFilter: ?[*:0]const u16,
    lpstrCustomFilter: ?*u16,
    nMaxCustFilter: u32,
    nFilterIndex: u32,
    lpstrFile: ?[*:0]u16,
    nMaxFile: u32,
    lpstrFileTitle: ?[*:0]u16,
    nMaxFileTitle: u32,
    lpstrInitialDir: ?[*:0]const u16,
    lpstrTitle: ?[*:0]const u16,
    Flags: u32,
    nFileOffset: u16,
    nFileExtension: u16,
    lpstrDefExt: ?[*:0]const u16,
    lCustData: LPARAM,
    lpfnHook: ?*anyopaque,
    lpTemplateName: ?[*:0]const u16,
    pvReserved: ?*anyopaque,
    dwReserved: u32,
    FlagsEx: u32,
};

extern "comdlg32" fn GetOpenFileNameW(args: *OPENFILENAMEW) callconv(.winapi) std.os.windows.BOOL;

pub fn main() !void {
    std.debug.print("Compiled successfully!\n", .{});
}
