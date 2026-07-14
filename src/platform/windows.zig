//! platform/windows.zig — Win32 + WebView2 backend
//!
//! Zig 0.16 compatible — all Win32 types defined locally.

const std = @import("std");
const App = @import("../app.zig").App;
const WindowConfig = @import("../window.zig").WindowConfig;
const WindowTheme = @import("../window.zig").WindowTheme;
const WebViewConfig = @import("../webview.zig").WebViewConfig;
const WebView = @import("../webview.zig").WebView;

// ─── Win32 primitive types ─────────────────────────────────────────────────────

const BOOL    = i32;
const HRESULT = i32;
const WPARAM  = usize;
const LPARAM  = isize;
const LRESULT = isize;

// Opaque handle types
const HWND      = *anyopaque;
const HMENU     = *anyopaque;
const HICON     = *anyopaque;
const HCURSOR   = *anyopaque;
const HBRUSH    = *anyopaque;
const HINSTANCE = *anyopaque;
const HMODULE   = *anyopaque;
const HKEY      = *anyopaque;
const LPCWSTR   = [*:0]const u16;
const WNDPROC   = *const fn (?*anyopaque, u32, WPARAM, LPARAM) callconv(.winapi) LRESULT;

const GUID = extern struct {
    Data1: u32,
    Data2: u16,
    Data3: u16,
    Data4: [8]u8,
};

// ─── kernel32 / advapi32 functions ────────────────────────────────────────────

extern "kernel32" fn GetModuleHandleW(lpModuleName: ?LPCWSTR) callconv(.winapi) ?HMODULE;
extern "kernel32" fn LoadLibraryW(lpLibFileName: LPCWSTR) callconv(.winapi) ?HMODULE;
extern "kernel32" fn GetProcAddress(hModule: HMODULE, lpProcName: [*:0]const u8) callconv(.winapi) ?*anyopaque;

extern "advapi32" fn RegOpenKeyExW(
    hKey: HKEY,
    lpSubKey: LPCWSTR,
    ulOptions: u32,
    samDesired: u32,
    phkResult: *HKEY,
) callconv(.winapi) i32;
extern "advapi32" fn RegQueryValueExW(
    hKey: HKEY,
    lpValueName: LPCWSTR,
    lpReserved: ?*u32,
    lpType: ?*u32,
    lpData: ?*anyopaque,
    lpcbData: ?*u32,
) callconv(.winapi) i32;
extern "advapi32" fn RegCloseKey(hKey: HKEY) callconv(.winapi) i32;
extern "kernel32" fn Sleep(dwMilliseconds: u32) callconv(.winapi) void;


// ─── Type aliases ─────────────────────────────────────────────────────────────

pub const WindowHandle = HWND;
pub const WebViewHandle = *WebView2State;

// Dummy pointer used as null COM completion handler
const IDummyScriptHandler = extern struct {
    vtable: *const VTable,
    const VTable = extern struct {
        QueryInterface: *const fn (*IUnknown, *const GUID, **anyopaque) callconv(.winapi) HRESULT,
        AddRef: *const fn (*IUnknown) callconv(.winapi) u32,
        Release: *const fn (*IUnknown) callconv(.winapi) u32,
        Invoke: *const fn (*anyopaque, HRESULT, [*:0]const u16) callconv(.winapi) HRESULT,
    };
};

fn dummy_script_QueryInterface(self: *IUnknown, riid: *const GUID, ppvObject: **anyopaque) callconv(.winapi) HRESULT {
    const E_NOINTERFACE: HRESULT = @bitCast(@as(u32, 0x80004002));
    
    // IUnknown
    if (riid.Data1 == 0x00000000 and riid.Data2 == 0x0000 and riid.Data3 == 0x0000 and riid.Data4[0] == 0xC0) {
        ppvObject.* = self;
        return 0;
    }
    
    // ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler: b99369f3-9b11-47b5-bc6f-8e7895fcea17
    if (riid.Data1 == 0xb99369f3) {
        ppvObject.* = self;
        return 0;
    }
    
    // ICoreWebView2ExecuteScriptCompletedHandler: 49511172-cc67-48bc-b15d-74d25d983208
    if (riid.Data1 == 0x49511172) {
        ppvObject.* = self;
        return 0;
    }
    
    return E_NOINTERFACE;
}
fn dummy_script_AddRef(_: *IUnknown) callconv(.winapi) u32 { return 1; }
fn dummy_script_Release(_: *IUnknown) callconv(.winapi) u32 { return 1; }
fn dummy_script_Invoke(_: *anyopaque, _: HRESULT, _: [*:0]const u16) callconv(.winapi) HRESULT { return 0; }

var _dummy_script_handler_storage = IDummyScriptHandler{
    .vtable = &IDummyScriptHandler.VTable{
        .QueryInterface = dummy_script_QueryInterface,
        .AddRef = dummy_script_AddRef,
        .Release = dummy_script_Release,
        .Invoke = dummy_script_Invoke,
    },
};

// ─── Win32 constants & types not in std ───────────────────────────────────────

const WS_OVERLAPPED: u32 = 0x00000000;
pub const WS_MAXIMIZEBOX = 0x00010000;
pub const WS_MINIMIZEBOX = 0x00020000;
pub const WS_THICKFRAME  = 0x00040000;
pub const WS_SYSMENU     = 0x00080000;
pub const WS_CAPTION     = 0x00C00000;
const WS_OVERLAPPEDWINDOW: u32 = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU |
    WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
const WS_VISIBLE: u32 = 0x10000000;
const WS_POPUP: u32 = 0x80000000;

const SW_SHOW: i32 = 5;
const SW_HIDE: i32 = 0;
const SW_MAXIMIZE: i32 = 3;
const SW_MINIMIZE: i32 = 6;
const SW_RESTORE: i32 = 9;
const SW_SHOWNORMAL: i32 = 1;

const CW_USEDEFAULT: i32 = @bitCast(@as(u32, 0x80000000));
const HWND_TOPMOST: HWND = @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))));
const HWND_NOTOPMOST: HWND = @ptrFromInt(@as(usize, @bitCast(@as(isize, -2))));
const SWP_NOMOVE: u32 = 0x0002;
const SWP_NOSIZE: u32 = 0x0001;
const SWP_FRAMECHANGED: u32 = 0x0020;

const DWMWA_USE_IMMERSIVE_DARK_MODE: u32 = 20;

const PM_REMOVE: u32 = 0x0001;

const WM_DESTROY: u32 = 0x0002;
const WM_SIZE: u32 = 0x0005;
const WM_CLOSE: u32 = 0x0010;
const WM_GETMINMAXINFO: u32 = 0x0024;
const WM_NCCREATE: u32 = 0x0081;

const CS_HREDRAW: u32 = 0x0002;
const CS_VREDRAW: u32 = 0x0001;
const COLOR_WINDOW: u32 = 5;
const IDI_APPLICATION = @as(HICON, @ptrFromInt(32512));
const IDC_ARROW = @as(HCURSOR, @ptrFromInt(32512));

const MINMAXINFO = extern struct {
    ptReserved: POINT,
    ptMaxSize: POINT,
    ptMaxPosition: POINT,
    ptMinTrackSize: POINT,
    ptMaxTrackSize: POINT,
};

const POINT = extern struct {
    x: i32,
    y: i32,
};

const RECT = extern struct {
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,
};

const WNDCLASSEXW = extern struct {
    cbSize: u32,
    style: u32,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32,
    cbWndExtra: i32,
    hInstance: HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH,
    lpszMenuName: ?[*:0]const u16,
    lpszClassName: [*:0]const u16,
    hIconSm: ?HICON,
};

const MSG = extern struct {
    hwnd: ?HWND,
    message: u32,
    wParam: WPARAM,
    lParam: LPARAM,
    time: u32,
    pt: POINT,
    lPrivate: u32,
};

const CREATESTRUCTW = extern struct {
    lpCreateParams: ?*anyopaque,
    hInstance: HINSTANCE,
    hMenu: ?HMENU,
    hwndParent: ?HWND,
    cy: i32,
    cx: i32,
    y: i32,
    x: i32,
    style: i32,
    lpszName: [*:0]const u16,
    lpszClass: [*:0]const u16,
    dwExStyle: u32,
};

// ─── Win32 extern functions ───────────────────────────────────────────────────

extern "user32" fn RegisterClassExW(lpwcx: *const WNDCLASSEXW) callconv(.winapi) u16;
extern "user32" fn CreateWindowExW(
    dwExStyle: u32,
    lpClassName: [*:0]const u16,
    lpWindowName: [*:0]const u16,
    dwStyle: u32,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWndParent: ?HWND,
    hMenu: ?HMENU,
    hInstance: HINSTANCE,
    lpParam: ?*anyopaque,
) callconv(.winapi) ?HWND;
extern "user32" fn DefWindowProcW(
    hWnd: HWND,
    Msg: u32,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) LRESULT;
extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: i32) callconv(.winapi) BOOL;
extern "user32" fn UpdateWindow(hWnd: HWND) callconv(.winapi) BOOL;
pub extern "user32" fn DestroyWindow(hWnd: HWND) callconv(.winapi) BOOL;
pub extern "user32" fn ReleaseCapture() callconv(.winapi) BOOL;
pub extern "user32" fn SendMessageA(hWnd: HWND, Msg: u32, wParam: usize, lParam: isize) callconv(.winapi) LRESULT;
extern "user32" fn SetWindowTextW(hWnd: HWND, lpString: [*:0]const u16) callconv(.winapi) BOOL;
extern "user32" fn SetWindowPos(
    hWnd: HWND,
    hWndInsertAfter: ?HWND,
    X: i32,
    Y: i32,
    cx: i32,
    cy: i32,
    uFlags: u32,
) callconv(.winapi) BOOL;
extern "user32" fn GetWindowRect(hWnd: HWND, lpRect: *RECT) callconv(.winapi) BOOL;
extern "user32" fn GetClientRect(hWnd: HWND, lpRect: *RECT) callconv(.winapi) BOOL;
extern "user32" fn GetSystemMetrics(nIndex: i32) callconv(.winapi) i32;
extern "user32" fn MoveWindow(
    hWnd: HWND,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    bRepaint: BOOL,
) callconv(.winapi) BOOL;
extern "user32" fn PeekMessageW(
    lpMsg: *MSG,
    hWnd: ?HWND,
    wMsgFilterMin: u32,
    wMsgFilterMax: u32,
    wRemoveMsg: u32,
) callconv(.winapi) BOOL;
extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.winapi) BOOL;
extern "user32" fn DispatchMessageW(lpMsg: *const MSG) callconv(.winapi) LRESULT;
extern "user32" fn PostQuitMessage(nExitCode: i32) callconv(.winapi) void;
extern "user32" fn LoadIconW(hInstance: ?HINSTANCE, lpIconName: LPCWSTR) callconv(.winapi) ?HICON;
extern "user32" fn LoadCursorW(hInstance: ?HINSTANCE, lpCursorName: LPCWSTR) callconv(.winapi) ?HCURSOR;
extern "user32" fn SetForegroundWindow(hWnd: HWND) callconv(.winapi) BOOL;
extern "user32" fn GetWindowLongPtrW(hWnd: HWND, nIndex: i32) callconv(.winapi) isize;
extern "user32" fn SetWindowLongPtrW(hWnd: HWND, nIndex: i32, dwNewLong: isize) callconv(.winapi) isize;

extern "ole32" fn CoInitializeEx(pvReserved: ?*anyopaque, dwCoInit: u32) callconv(.winapi) HRESULT;
extern "ole32" fn CoUninitialize() callconv(.winapi) void;

extern "dwmapi" fn DwmSetWindowAttribute(
    hwnd: HWND,
    dwAttribute: u32,
    pvAttribute: *const anyopaque,
    cbAttribute: u32,
) callconv(.winapi) HRESULT;

const GWLP_USERDATA: i32 = -21;
const SM_CXSCREEN: i32 = 0;
const SM_CYSCREEN: i32 = 1;
const COINIT_APARTMENTTHREADED: u32 = 0x2;

// ─── Window class name ────────────────────────────────────────────────────────

const WINDOW_CLASS_NAME = std.unicode.utf8ToUtf16LeStringLiteral("NauriKitWindow");

// ─── Per-window state ─────────────────────────────────────────────────────────

const WindowState = struct {
    app: *App,
    window: *@import("../window.zig").Window,
    min_width: u32,
    min_height: u32,
};

// ─── COM / INIT ──────────────────────────────────────────────────────────────

pub fn initCOM() !void {
    const hr = CoInitializeEx(null, COINIT_APARTMENTTHREADED);
    if (hr < 0) return error.COMInitFailed;
}

pub fn uninitCOM() void {
    CoUninitialize();
}

// ─── Event loop ───────────────────────────────────────────────────────────────

pub fn runEventLoop(app: *App) !void {
    var msg: MSG = undefined;
    while (app.running) {
        while (PeekMessageW(&msg, null, 0, 0, PM_REMOVE) != 0) {
            if (msg.message == 0x0012) { // WM_QUIT
                return;
            }
            _ = TranslateMessage(&msg);
            _ = DispatchMessageW(&msg);
        }
        // Pump WebView2 messages
        for (app.windows.items) |w| {
            if (w.webview) |wv| {
                webView2Pump(wv.handle);
            }
        }
        // Yield to avoid busy-waiting
        Sleep(1);
    }
}

pub fn postQuitMessage(code: i32) void {
    PostQuitMessage(code);
}

// ─── Window creation ──────────────────────────────────────────────────────────

var class_registered: bool = false;

fn ensureClassRegistered(hInstance: HINSTANCE) !void {
    if (class_registered) return;

    const wc = WNDCLASSEXW{
        .cbSize = @sizeOf(WNDCLASSEXW),
        .style = CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc = windowProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = hInstance,
        .hIcon = LoadIconW(null, @ptrFromInt(32512)),
        .hCursor = LoadCursorW(null, @ptrFromInt(32512)),
        .hbrBackground = @ptrFromInt(COLOR_WINDOW + 1),
        .lpszMenuName = null,
        .lpszClassName = WINDOW_CLASS_NAME,
        .hIconSm = LoadIconW(null, @ptrFromInt(32512)),
    };

    if (RegisterClassExW(&wc) == 0) return error.ClassRegistrationFailed;
    class_registered = true;
}

pub fn createWindow(app: *@import("../app.zig").App, config: @import("../window.zig").WindowOptions) !WindowHandle {
    const title_w = try std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, config.title);
    defer std.heap.page_allocator.free(title_w);

    const style = if (config.frameless)
        (WS_POPUP | WS_THICKFRAME | WS_SYSMENU | WS_MAXIMIZEBOX | WS_MINIMIZEBOX)
    else
        WS_OVERLAPPEDWINDOW;

    const hInstance = GetModuleHandleW(null) orelse return error.NoModuleHandle;
    try ensureClassRegistered(hInstance);

    const hwnd = CreateWindowExW(
        0,
        WINDOW_CLASS_NAME,
        title_w.ptr,
        style | WS_VISIBLE,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        @intCast(config.width),
        @intCast(config.height),
        null,
        null,
        hInstance,
        null,
    ) orelse return error.WindowCreationFailed;

    // Store app pointer in window userdata
    _ = SetWindowLongPtrW(hwnd, GWLP_USERDATA, @bitCast(@intFromPtr(app)));

    _ = UpdateWindow(hwnd);
    return hwnd;
}

pub fn destroyWindow(hwnd: WindowHandle) void {
    _ = DestroyWindow(hwnd);
}

// ─── Window properties ────────────────────────────────────────────────────────

pub fn showWindow(hwnd: WindowHandle) void {
    _ = ShowWindow(hwnd, SW_SHOW);
}

pub fn hideWindow(hwnd: WindowHandle) void {
    _ = ShowWindow(hwnd, SW_HIDE);
}

pub fn focusWindow(hwnd: WindowHandle) void {
    _ = SetForegroundWindow(hwnd);
}

pub fn maximizeWindow(hwnd: WindowHandle) void {
    _ = ShowWindow(hwnd, SW_MAXIMIZE);
}

pub fn minimizeWindow(hwnd: WindowHandle) void {
    _ = ShowWindow(hwnd, SW_MINIMIZE);
}

pub fn windowRestore(handle: WindowHandle) void {
    _ = ShowWindow(handle, SW_RESTORE);
}

pub fn windowStartDrag(handle: WindowHandle) void {
    _ = ReleaseCapture();
    _ = SendMessageA(handle, 0x00A1, 2, 0); // WM_NCLBUTTONDOWN = 0x00A1, HTCAPTION = 2
}

pub fn setWindowTitle(hwnd: WindowHandle, title: []const u8) void {
    var buf: [512]u16 = undefined;
    const w = toUtf16(&buf, title) catch return;
    _ = SetWindowTextW(hwnd, w);
}

pub fn setWindowSize(hwnd: WindowHandle, width: u32, height: u32) void {
    _ = SetWindowPos(hwnd, null, 0, 0, @intCast(width), @intCast(height), SWP_NOMOVE);
}

pub fn setWindowMinSize(hwnd: WindowHandle, width: u32, height: u32) void {
    _ = hwnd;
    _ = width;
    _ = height;
    // Stored in MINMAXINFO handler; we use GWLP_USERDATA for app ptr.
    // For simplicity, min size is stored in WindowConfig which is accessible
    // via the Window struct. The WM_GETMINMAXINFO handler reads it.
}

pub fn centerWindow(hwnd: WindowHandle) void {
    var rect: RECT = undefined;
    _ = GetWindowRect(hwnd, &rect);
    const w = rect.right - rect.left;
    const h = rect.bottom - rect.top;
    const sw = GetSystemMetrics(SM_CXSCREEN);
    const sh = GetSystemMetrics(SM_CYSCREEN);
    const x = @divTrunc(sw - w, 2);
    const y = @divTrunc(sh - h, 2);
    _ = SetWindowPos(hwnd, null, x, y, 0, 0, SWP_NOSIZE);
}

pub fn setWindowAlwaysOnTop(hwnd: WindowHandle, enable: bool) void {
    const insert_after = if (enable) HWND_TOPMOST else HWND_NOTOPMOST;
    _ = SetWindowPos(hwnd, insert_after, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
}

pub fn setWindowTheme(hwnd: WindowHandle, theme: WindowTheme) void {
    const dark: BOOL = switch (theme) {
        .dark => 1,
        .light => 0,
        .system => blk: {
            // Read system preference from registry
            break :blk isSystemDarkMode();
        },
    };
    _ = DwmSetWindowAttribute(
        hwnd,
        DWMWA_USE_IMMERSIVE_DARK_MODE,
        &dark,
        @sizeOf(BOOL),
    );
}

fn isSystemDarkMode() BOOL {
    // Read HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\AppsUseLightTheme
    var data: u32 = 1;
    var size: u32 = @sizeOf(u32);
    const key_path = std.unicode.utf8ToUtf16LeStringLiteral(
        "Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
    );
    const value_name = std.unicode.utf8ToUtf16LeStringLiteral("AppsUseLightTheme");

    const HKEY_CURRENT_USER: HKEY = @ptrFromInt(0x80000001);
    var hkey: HKEY = undefined;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, key_path, 0, 0x20019, &hkey) == 0) {
        _ = RegQueryValueExW(hkey, value_name, null, null, @ptrCast(&data), &size);
        _ = RegCloseKey(hkey);
    }
    return if (data == 0) 1 else 0; // 0 = dark mode enabled
}

// ─── Win32 Window Procedure ───────────────────────────────────────────────────

fn windowProc(
    hwnd_opt: ?*anyopaque,
    msg: u32,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) LRESULT {
    const hwnd = hwnd_opt orelse return 0; // null HWND - nothing to process
    switch (msg) {
        WM_SIZE => {
            // Resize WebView to match window
            const app_ptr = GetWindowLongPtrW(hwnd, GWLP_USERDATA);
            if (app_ptr != 0) {
                const app: *App = @ptrFromInt(@as(usize, @bitCast(app_ptr)));
                for (app.windows.items) |w| {
                    if (w.handle == hwnd) {
                        if (w.webview) |wv| {
                            var rect: RECT = undefined;
                            _ = GetClientRect(hwnd, &rect);
                            webView2Resize(
                                wv.handle,
                                @intCast(rect.right),
                                @intCast(rect.bottom),
                            );
                        }
                        break;
                    }
                }
            }
            return 0;
        },
        WM_GETMINMAXINFO => {
            const info: *MINMAXINFO = @ptrFromInt(@as(usize, @bitCast(lParam)));
            const app_ptr = GetWindowLongPtrW(hwnd, GWLP_USERDATA);
            if (app_ptr != 0) {
                const app: *App = @ptrFromInt(@as(usize, @bitCast(app_ptr)));
                for (app.windows.items) |w| {
                    if (w.handle == hwnd) {
                        info.ptMinTrackSize.x = @intCast(w.config.min_width);
                        info.ptMinTrackSize.y = @intCast(w.config.min_height);
                        break;
                    }
                }
            }
            return 0;
        },
        WM_CLOSE => {
            const app_ptr = GetWindowLongPtrW(hwnd, GWLP_USERDATA);
            if (app_ptr != 0) {
                const app: *App = @ptrFromInt(@as(usize, @bitCast(app_ptr)));
                for (app.windows.items) |w| {
                    if (w.handle == hwnd) {
                        app.removeWindow(w);
                        break;
                    }
                }
            }
            _ = DestroyWindow(hwnd);
            return 0;
        },
        WM_DESTROY => {
            return 0;
        },
        else => return DefWindowProcW(hwnd, msg, wParam, lParam),
    }
}

// ─── WebView2 State ───────────────────────────────────────────────────────────

pub const WebView2State = struct {
    naurikit_wv: *WebView,
    controller: ?*IWebView2Controller,
    webview: ?*IWebView2WebView,
    hwnd: HWND,
    ready: bool,
    pending_navigations: std.ArrayList([]const u8),
    pending_htmls: std.ArrayList([]const u8),
    pending_scripts: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
};

// ─── WebView2 COM interfaces (minimal subset needed) ──────────────────────────
// We use a hand-translated subset of the WebView2 COM API.
// This avoids C header dependencies entirely.

const IUnknown = extern struct {
    vtable: *const IUnknownVTable,

    const IUnknownVTable = extern struct {
        QueryInterface: *const fn (self: *IUnknown, riid: *const GUID, ppvObject: **anyopaque) callconv(.winapi) HRESULT,
        AddRef: *const fn (self: *IUnknown) callconv(.winapi) u32,
        Release: *const fn (self: *IUnknown) callconv(.winapi) u32,
    };

    pub fn release(self: *IUnknown) void {
        _ = self.vtable.Release(self);
    }
};

// ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler
const IEnvCreatedHandler = extern struct {
    vtable: *const VTable,
    refcount: u32 = 1,
    state: *WebView2State,

    const VTable = extern struct {
        QueryInterface: *const fn (*IUnknown, *const GUID, **anyopaque) callconv(.winapi) HRESULT,
        AddRef: *const fn (*IUnknown) callconv(.winapi) u32,
        Release: *const fn (*IUnknown) callconv(.winapi) u32,
        Invoke: *const fn (*IEnvCreatedHandler, HRESULT, ?*ICoreWebView2Environment) callconv(.winapi) HRESULT,
    };
};

// ICoreWebView2CreateCoreWebView2ControllerCompletedHandler
const ICtrlCreatedHandler = extern struct {
    vtable: *const VTable,
    refcount: u32 = 1,
    state: *WebView2State,

    const VTable = extern struct {
        QueryInterface: *const fn (*IUnknown, *const GUID, **anyopaque) callconv(.winapi) HRESULT,
        AddRef: *const fn (*IUnknown) callconv(.winapi) u32,
        Release: *const fn (*IUnknown) callconv(.winapi) u32,
        Invoke: *const fn (*ICtrlCreatedHandler, HRESULT, ?*IWebView2Controller) callconv(.winapi) HRESULT,
    };
};

const ICoreWebView2Environment = extern struct {
    vtable: *const VTable,

    const VTable = extern struct {
        QueryInterface: *const fn (*IUnknown, *const GUID, **anyopaque) callconv(.winapi) HRESULT,
        AddRef: *const fn (*IUnknown) callconv(.winapi) u32,
        Release: *const fn (*IUnknown) callconv(.winapi) u32,
        CreateCoreWebView2Controller: *const fn (
            *ICoreWebView2Environment,
            HWND,
            *ICtrlCreatedHandler,
        ) callconv(.winapi) HRESULT,
        // ...more methods we don't use
        _pad: [8]*anyopaque,
    };
};

const IWebView2Controller = extern struct {
    vtable: *const VTable,

    const VTable = extern struct {
        QueryInterface: *const fn (*IUnknown, *const GUID, **anyopaque) callconv(.winapi) HRESULT,
        AddRef: *const fn (*IUnknown) callconv(.winapi) u32,
        Release: *const fn (*IUnknown) callconv(.winapi) u32,
        get_IsVisible: *const fn (*IWebView2Controller, *BOOL) callconv(.winapi) HRESULT,
        put_IsVisible: *const fn (*IWebView2Controller, BOOL) callconv(.winapi) HRESULT,
        get_Bounds: *const fn (*IWebView2Controller, *RECT) callconv(.winapi) HRESULT,
        put_Bounds: *const fn (*IWebView2Controller, RECT) callconv(.winapi) HRESULT,
        get_ZoomFactor: *const fn (*IWebView2Controller, *f64) callconv(.winapi) HRESULT,
        put_ZoomFactor: *const fn (*IWebView2Controller, f64) callconv(.winapi) HRESULT,
        _pad1: [16]*anyopaque,
        get_CoreWebView2: *const fn (*IWebView2Controller, *?*IWebView2WebView) callconv(.winapi) HRESULT,
    };
};

const IWebView2WebView = extern struct {
    vtable: *const VTable,

    const VTable = extern struct {
        QueryInterface: *const fn (*IUnknown, *const GUID, **anyopaque) callconv(.winapi) HRESULT,
        AddRef: *const fn (*IUnknown) callconv(.winapi) u32,
        Release: *const fn (*IUnknown) callconv(.winapi) u32,
        get_Settings: *const fn (*IWebView2WebView, **anyopaque) callconv(.winapi) HRESULT,
        get_Source: *const fn (*IWebView2WebView, *?[*:0]u16) callconv(.winapi) HRESULT,
        Navigate: *const fn (*IWebView2WebView, [*:0]const u16) callconv(.winapi) HRESULT,
        NavigateToString: *const fn (*IWebView2WebView, [*:0]const u16) callconv(.winapi) HRESULT,
        add_NavigationStarting: *const fn (*IWebView2WebView, *anyopaque, *i64) callconv(.winapi) HRESULT,
        remove_NavigationStarting: *const fn (*IWebView2WebView, i64) callconv(.winapi) HRESULT,
        add_ContentLoading: *const fn (*IWebView2WebView, *anyopaque, *i64) callconv(.winapi) HRESULT,
        remove_ContentLoading: *const fn (*IWebView2WebView, i64) callconv(.winapi) HRESULT,
        add_SourceChanged: *const fn (*IWebView2WebView, *anyopaque, *i64) callconv(.winapi) HRESULT,
        remove_SourceChanged: *const fn (*IWebView2WebView, i64) callconv(.winapi) HRESULT,
        add_HistoryChanged: *const fn (*IWebView2WebView, *anyopaque, *i64) callconv(.winapi) HRESULT,
        remove_HistoryChanged: *const fn (*IWebView2WebView, i64) callconv(.winapi) HRESULT,
        add_NavigationCompleted: *const fn (*IWebView2WebView, *anyopaque, *i64) callconv(.winapi) HRESULT,
        remove_NavigationCompleted: *const fn (*IWebView2WebView, i64) callconv(.winapi) HRESULT,
        add_FrameNavigationStarting: *const fn (*IWebView2WebView, *anyopaque, *i64) callconv(.winapi) HRESULT,
        remove_FrameNavigationStarting: *const fn (*IWebView2WebView, i64) callconv(.winapi) HRESULT,
        add_FrameNavigationCompleted: *const fn (*IWebView2WebView, *anyopaque, *i64) callconv(.winapi) HRESULT,
        remove_FrameNavigationCompleted: *const fn (*IWebView2WebView, i64) callconv(.winapi) HRESULT,
        add_ScriptDialogOpening: *const fn (*IWebView2WebView, *anyopaque, *i64) callconv(.winapi) HRESULT,
        remove_ScriptDialogOpening: *const fn (*IWebView2WebView, i64) callconv(.winapi) HRESULT,
        add_PermissionRequested: *const fn (*IWebView2WebView, *anyopaque, *i64) callconv(.winapi) HRESULT,
        remove_PermissionRequested: *const fn (*IWebView2WebView, i64) callconv(.winapi) HRESULT,
        add_ProcessFailed: *const fn (*IWebView2WebView, *anyopaque, *i64) callconv(.winapi) HRESULT,
        remove_ProcessFailed: *const fn (*IWebView2WebView, i64) callconv(.winapi) HRESULT,
        AddScriptToExecuteOnDocumentCreated: *const fn (*IWebView2WebView, [*:0]const u16, ?*anyopaque) callconv(.winapi) HRESULT,
        RemoveScriptToExecuteOnDocumentCreated: *const fn (*IWebView2WebView, [*:0]const u16) callconv(.winapi) HRESULT,
        ExecuteScript: *const fn (*IWebView2WebView, [*:0]const u16, ?*anyopaque) callconv(.winapi) HRESULT,
        CapturePreview: *const fn (*IWebView2WebView, i32, *anyopaque, *anyopaque) callconv(.winapi) HRESULT,
        Reload: *const fn (*IWebView2WebView) callconv(.winapi) HRESULT,
        PostWebMessageAsJson: *const fn (*IWebView2WebView, [*:0]const u16) callconv(.winapi) HRESULT,
        PostWebMessageAsString: *const fn (*IWebView2WebView, [*:0]const u16) callconv(.winapi) HRESULT,
        add_WebMessageReceived: *const fn (*IWebView2WebView, *IWebMessageReceivedHandler, *i64) callconv(.winapi) HRESULT,
        remove_WebMessageReceived: *const fn (*IWebView2WebView, i64) callconv(.winapi) HRESULT,
        CallDevToolsProtocolMethod: *const fn (*IWebView2WebView, [*:0]const u16, [*:0]const u16, *anyopaque) callconv(.winapi) HRESULT,
        get_BrowserProcessId: *const fn (*IWebView2WebView, *u32) callconv(.winapi) HRESULT,
        get_CanGoBack: *const fn (*IWebView2WebView, *BOOL) callconv(.winapi) HRESULT,
        get_CanGoForward: *const fn (*IWebView2WebView, *BOOL) callconv(.winapi) HRESULT,
        GoBack: *const fn (*IWebView2WebView) callconv(.winapi) HRESULT,
        GoForward: *const fn (*IWebView2WebView) callconv(.winapi) HRESULT,
        OpenDevToolsWindow: *const fn (*IWebView2WebView) callconv(.winapi) HRESULT,
    };
};

const IWebMessageReceivedHandler = extern struct {
    vtable: *const VTable,
    refcount: u32 = 1,
    state: *WebView2State,

    const VTable = extern struct {
        QueryInterface: *const fn (*IUnknown, *const GUID, **anyopaque) callconv(.winapi) HRESULT,
        AddRef: *const fn (*IUnknown) callconv(.winapi) u32,
        Release: *const fn (*IUnknown) callconv(.winapi) u32,
        Invoke: *const fn (*IWebMessageReceivedHandler, *IWebView2WebView, *IWebMessageReceivedEventArgs) callconv(.winapi) HRESULT,
    };
};

const IWebMessageReceivedEventArgs = extern struct {
    vtable: *const VTable,

    const VTable = extern struct {
        QueryInterface: *const fn (*IUnknown, *const GUID, **anyopaque) callconv(.winapi) HRESULT,
        AddRef: *const fn (*IUnknown) callconv(.winapi) u32,
        Release: *const fn (*IUnknown) callconv(.winapi) u32,
        get_Source: *const fn (*IWebMessageReceivedEventArgs, *?[*:0]u16) callconv(.winapi) HRESULT,
        get_WebMessageAsJson: *const fn (*IWebMessageReceivedEventArgs, *?[*:0]u16) callconv(.winapi) HRESULT,
        TryGetWebMessageAsString: *const fn (*IWebMessageReceivedEventArgs, *?[*:0]u16) callconv(.winapi) HRESULT,
    };
};

// WebView2 factory function loaded at runtime
const CreateWebViewEnvFn = *const fn (
    browserExePath: ?[*:0]const u16,
    userDataFolder: ?[*:0]const u16,
    additionalBrowserArguments: ?[*:0]const u16,
    handler: *IEnvCreatedHandler,
) callconv(.winapi) HRESULT;

// ─── WebView2 loader ──────────────────────────────────────────────────────────

var webview2_dll: ?HMODULE = null;
var createWebViewEnv: ?CreateWebViewEnvFn = null;

fn loadWebView2() !void {
    if (webview2_dll != null) return;

    const dll_name = std.unicode.utf8ToUtf16LeStringLiteral("WebView2Loader.dll");
    webview2_dll = LoadLibraryW(dll_name);
    if (webview2_dll == null) return error.WebView2NotInstalled;

    const proc = GetProcAddress(
        webview2_dll.?,
        "CreateCoreWebView2EnvironmentWithOptions",
    );
    if (proc == null) return error.WebView2ApiMissing;
    createWebViewEnv = @ptrCast(proc);
}

// ─── COM handler implementations (vtables) ────────────────────────────────────

// We allocate COM handler objects on the heap because WebView2 will call
// them asynchronously. Zig comptime vtables keep binary size minimal.

fn makeEnvHandler(allocator: std.mem.Allocator, state: *WebView2State) !*IEnvCreatedHandler {
    const S = struct {
        const vtable = IEnvCreatedHandler.VTable{
            .QueryInterface = qiNoop,
            .AddRef = addRefNoop,
            .Release = releaseNoop,
            .Invoke = envInvoke,
        };

        fn qiNoop(self: *IUnknown, riid: *const GUID, ppv: **anyopaque) callconv(.winapi) HRESULT {
            const E_NOINTERFACE: HRESULT = @bitCast(@as(u32, 0x80004002));
            if (riid.Data1 == 0 or riid.Data1 > 1000) { 
                ppv.* = self;
                return 0;
            }
            return E_NOINTERFACE;
        }
        fn addRefNoop(self: *IUnknown) callconv(.winapi) u32 {
            const h: *IEnvCreatedHandler = @ptrCast(self);
            h.refcount += 1;
            return h.refcount;
        }
        fn releaseNoop(self: *IUnknown) callconv(.winapi) u32 {
            const h: *IEnvCreatedHandler = @ptrCast(self);
            h.refcount -= 1;
            return h.refcount;
        }

        fn envInvoke(
            self: *IEnvCreatedHandler,
            hr: HRESULT,
            env: ?*ICoreWebView2Environment,
        ) callconv(.winapi) HRESULT {
            if (hr < 0 or env == null) {
                std.log.err("WebView2: env creation failed: 0x{X}", .{@as(u32, @bitCast(hr))});
                return 0;
            }
            const wv2_state = self.state;
            // Now create the controller
            const ctrl_handler = makeCtrlHandler(wv2_state.allocator, wv2_state) catch return 0;
            _ = env.?.vtable.CreateCoreWebView2Controller(env.?, wv2_state.hwnd, ctrl_handler);
            return 0;
        }
    };

    const h = try allocator.create(IEnvCreatedHandler);
    h.* = .{
        .vtable = &S.vtable,
        .refcount = 1,
        .state = state,
    };
    return h;
}

fn WebView2StateAllocatorHelper(state: *WebView2State) std.mem.Allocator {
    return state.allocator;
}

fn makeCtrlHandler(allocator: std.mem.Allocator, state: *WebView2State) !*ICtrlCreatedHandler {
    const S = struct {
        const vtable = ICtrlCreatedHandler.VTable{
            .QueryInterface = qiNoop,
            .AddRef = addRefNoop,
            .Release = releaseNoop,
            .Invoke = ctrlInvoke,
        };

        fn qiNoop(self: *IUnknown, riid: *const GUID, ppv: **anyopaque) callconv(.winapi) HRESULT {
            const E_NOINTERFACE: HRESULT = @bitCast(@as(u32, 0x80004002));
            if (riid.Data1 == 0 or riid.Data1 > 1000) { 
                ppv.* = self;
                return 0;
            }
            return E_NOINTERFACE;
        }
        fn addRefNoop(self: *IUnknown) callconv(.winapi) u32 {
            const h: *ICtrlCreatedHandler = @ptrCast(self);
            h.refcount += 1;
            return h.refcount;
        }
        fn releaseNoop(self: *IUnknown) callconv(.winapi) u32 {
            const h: *ICtrlCreatedHandler = @ptrCast(self);
            h.refcount -= 1;
            return h.refcount;
        }

        fn ctrlInvoke(
            self: *ICtrlCreatedHandler,
            hr: HRESULT,
            controller: ?*IWebView2Controller,
        ) callconv(.winapi) HRESULT {
            if (hr < 0 or controller == null) {
                std.log.err("WebView2: controller creation failed: 0x{X}", .{@as(u32, @bitCast(hr))});
                return 0;
            }

            const wv2_state = self.state;
            _ = controller.?.vtable.AddRef(@ptrCast(controller.?));
            wv2_state.controller = controller;

            // Get the webview interface
            var wv: ?*IWebView2WebView = null;
            _ = controller.?.vtable.get_CoreWebView2(controller.?, &wv);
            wv2_state.webview = wv;

            // Set initial bounds
            var rect: RECT = undefined;
            _ = GetClientRect(wv2_state.hwnd, &rect);
            _ = controller.?.vtable.put_Bounds(controller.?, rect);

            // Register IPC message handler
            const msg_handler = makeMsgHandler(wv2_state.allocator, wv2_state) catch return 0;
            var token: i64 = 0;
            _ = wv.?.vtable.add_WebMessageReceived(wv.?, msg_handler, &token);

            wv2_state.ready = true;

            // Flush pending init scripts
            for (wv2_state.pending_scripts.items) |script| {
                const w = std.unicode.utf8ToUtf16LeAllocZ(wv2_state.allocator, script) catch continue;
                defer wv2_state.allocator.free(w);
                const hr_script = wv.?.vtable.AddScriptToExecuteOnDocumentCreated(wv.?, w.ptr, &_dummy_script_handler_storage);
                if (hr_script < 0) std.debug.print("AddScript failed: {x}\n", .{@as(u32, @bitCast(hr_script))});
            }
            wv2_state.pending_scripts.clearAndFree(wv2_state.allocator);

            // Flush pending navigations
            for (wv2_state.pending_navigations.items) |url| {
                const w = std.unicode.utf8ToUtf16LeAllocZ(wv2_state.allocator, url) catch continue;
                defer wv2_state.allocator.free(w);
                const hr_nav = wv.?.vtable.Navigate(wv.?, w.ptr);
                if (hr_nav < 0) {
                    std.debug.print("WebView2 Navigate in ctrlInvoke failed with HRESULT 0x{x}\n", .{@as(u32, @bitCast(hr_nav))});
                }
            }
            wv2_state.pending_navigations.clearAndFree(wv2_state.allocator);

            // Flush pending HTML
            for (wv2_state.pending_htmls.items) |html| {
                const w = std.unicode.utf8ToUtf16LeAllocZ(wv2_state.allocator, html) catch continue;
                defer wv2_state.allocator.free(w);
                _ = wv.?.vtable.NavigateToString(wv.?, w.ptr);
            }
            wv2_state.pending_htmls.clearAndFree(wv2_state.allocator);

            return 0;
        }
    };

    const h = try allocator.create(ICtrlCreatedHandler);
    h.* = .{
        .vtable = &S.vtable,
        .refcount = 1,
        .state = state,
    };
    return h;
}

fn makeMsgHandler(allocator: std.mem.Allocator, state: *WebView2State) !*IWebMessageReceivedHandler {
    const S = struct {
        const vtable = IWebMessageReceivedHandler.VTable{
            .QueryInterface = qiNoop,
            .AddRef = addRefNoop,
            .Release = releaseNoop,
            .Invoke = msgInvoke,
        };

        fn qiNoop(self: *IUnknown, riid: *const GUID, ppv: **anyopaque) callconv(.winapi) HRESULT {
            const E_NOINTERFACE: HRESULT = @bitCast(@as(u32, 0x80004002));
            if (riid.Data1 == 0 or riid.Data1 > 1000) { 
                ppv.* = self;
                return 0;
            }
            return E_NOINTERFACE;
        }
        fn addRefNoop(self: *IUnknown) callconv(.winapi) u32 {
            const h: *IWebMessageReceivedHandler = @ptrCast(self);
            h.refcount += 1;
            return h.refcount;
        }
        fn releaseNoop(self: *IUnknown) callconv(.winapi) u32 {
            const h: *IWebMessageReceivedHandler = @ptrCast(self);
            h.refcount -= 1;
            return h.refcount;
        }

        fn msgInvoke(
            self: *IWebMessageReceivedHandler,
            _: *IWebView2WebView,
            args: *IWebMessageReceivedEventArgs,
        ) callconv(.winapi) HRESULT {
            var json_w: ?[*:0]u16 = null;
            const hr = args.vtable.TryGetWebMessageAsString(args, &json_w);
            if (hr < 0 or json_w == null) return 0;

            // Convert UTF-16 -> UTF-8
            var buf: [65536]u8 = undefined;
            const len = std.unicode.utf16LeToUtf8(&buf, std.mem.span(json_w.?)) catch return 0;
            const json_str = buf[0..len];

            // Dispatch to IPC
            self.state.naurikit_wv.handleIpcMessage(json_str);
            return 0;
        }
    };

    const h = try allocator.create(IWebMessageReceivedHandler);
    h.* = .{
        .vtable = &S.vtable,
        .refcount = 1,
        .state = state,
    };
    return h;
}

// ─── WebView2 public API ──────────────────────────────────────────────────────

pub fn createWebView(
    window: *@import("../window.zig").Window,
    naurikit_wv: *WebView,
    config: WebViewConfig,
) !WebViewHandle {
    _ = config; // WebView2 settings applied after init via dedicated API
    try loadWebView2();

    const allocator = window.app.allocator;
    const state = try allocator.create(WebView2State);
    state.* = .{
        .naurikit_wv = naurikit_wv,
        .controller = null,
        .webview = null,
        .hwnd = window.handle,
        .ready = false,
        .pending_navigations = std.ArrayList([]const u8).empty,
        .pending_htmls = std.ArrayList([]const u8).empty,
        .pending_scripts = std.ArrayList([]const u8).empty,
        .allocator = allocator,
    };

    const env_handler = try makeEnvHandler(allocator, state);

    const hr = createWebViewEnv.?(null, null, null, env_handler);
    if (hr < 0) return error.WebView2EnvCreationFailed;

    return state;
}

pub fn destroyWebView(handle: WebViewHandle) void {
    if (handle.controller) |ctrl| {
        _ = ctrl.vtable.put_IsVisible(ctrl, 0);
    }
    handle.pending_navigations.deinit(handle.allocator);
    handle.pending_htmls.deinit(handle.allocator);
    handle.pending_scripts.deinit(handle.allocator);
    handle.allocator.destroy(handle);
}

pub fn webView2Pump(_: WebViewHandle) void {
    // WebView2 on Windows pumps via the COM message loop automatically.
    // Nothing extra needed here.
}

pub fn webView2Resize(handle: WebViewHandle, width: u32, height: u32) void {
    const ctrl = handle.controller orelse return;
    const rect = RECT{
        .left = 0,
        .top = 0,
        .right = @intCast(width),
        .bottom = @intCast(height),
    };
    _ = ctrl.vtable.put_Bounds(ctrl, rect);
}

pub fn webViewNavigate(handle: WebViewHandle, url: []const u8) !void {
    if (!handle.ready) {
        // Queue for later
        const owned = try handle.allocator.dupe(u8, url);
        try handle.pending_navigations.append(handle.allocator, owned);
        return;
    }
    const wv = handle.webview orelse return error.WebViewNotReady;
    const w = try std.unicode.utf8ToUtf16LeAllocZ(handle.allocator, url);
    defer handle.allocator.free(w);
    const hr = wv.vtable.Navigate(wv, w.ptr);
    if (hr < 0) {
        std.debug.print("WebView2 Navigate failed with HRESULT 0x{x}\n", .{@as(u32, @bitCast(hr))});
    }
    if (hr < 0) return error.NavigationFailed;
}

pub fn webViewLoadHtml(handle: WebViewHandle, html: []const u8) !void {
    if (!handle.ready) {
        const owned = try handle.allocator.dupe(u8, html);
        try handle.pending_htmls.append(handle.allocator, owned);
        return;
    }
    const wv = handle.webview orelse return error.WebViewNotReady;
    const w = try std.unicode.utf8ToUtf16LeAllocZ(handle.allocator, html);
    defer handle.allocator.free(w);
    const hr = wv.vtable.NavigateToString(wv, w.ptr);
    if (hr < 0) return error.LoadHtmlFailed;
}

pub fn webViewAddInitScript(handle: WebViewHandle, script: []const u8) !void {
    if (!handle.ready) {
        const owned = try handle.allocator.dupe(u8, script);
        try handle.pending_scripts.append(handle.allocator, owned);
        return;
    }
    const wv = handle.webview orelse return error.WebViewNotReady;
    const w = try std.unicode.utf8ToUtf16LeAllocZ(handle.allocator, script);
    defer handle.allocator.free(w);
    _ = wv.vtable.AddScriptToExecuteOnDocumentCreated(wv, w.ptr, &_dummy_script_handler_storage);
}

pub fn webViewEval(handle: WebViewHandle, js: []const u8) !void {
    const w = try std.unicode.utf8ToUtf16LeAllocZ(handle.allocator, js);
    defer handle.allocator.free(w);
    if (handle.webview) |wv| {
        const hr = wv.vtable.ExecuteScript(wv, w.ptr, null);
        if (hr < 0) return error.ScriptExecutionFailed;
    } else {
        return error.NotReady;
    }
}

pub fn webViewEvalWithResult(
    _: WebViewHandle,
    _: []const u8,
    _: *const fn ([]const u8) void,
) !void {
    // TODO: implement via ExecuteScript completion handler
    return error.NotImplemented;
}

pub fn webViewReload(handle: WebViewHandle) void {
    const wv = handle.webview orelse return;
    _ = wv.vtable.Reload(wv);
}

pub fn webViewGoBack(handle: WebViewHandle) void {
    const wv = handle.webview orelse return;
    _ = wv.vtable.GoBack(wv);
}

pub fn webViewGoForward(handle: WebViewHandle) void {
    const wv = handle.webview orelse return;
    _ = wv.vtable.GoForward(wv);
}

pub fn webViewOpenDevTools(handle: WebViewHandle) void {
    const wv = handle.webview orelse return;
    _ = wv.vtable.OpenDevToolsWindow(wv);
}

// ─── Utility: UTF-8 → UTF-16LE ───────────────────────────────────────────────

fn toUtf16(buf: []u16, utf8: []const u8) ![:0]const u16 {
    const written = try std.unicode.utf8ToUtf16Le(buf[0 .. buf.len - 1], utf8);
    buf[written] = 0;
    return buf[0..written :0];
}






