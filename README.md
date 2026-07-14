# NauriKit

> ⚡ Ultra-lightweight desktop app framework — Tauri alternative built with Zig

**NauriKit** uses the system's native WebView engine (WebView2 on Windows, WebKitGTK on Linux) and a Zig-powered backend for minimal binary size and blazing-fast startup.

## Why NauriKit?

| | Tauri | Electron | **NauriKit** |
|---|---|---|---|
| Backend | Rust | Node.js | **Zig** |
| Binary size | ~3–8 MB | ~80–150 MB | **~100–500 KB** |
| Compile time | ~30–60s | — | **~2–5s** |
| WebView | System | Bundled Chromium | **System** |
| Memory (idle) | ~40 MB | ~120 MB | **~15 MB** |
| Cross-compile | Hard | No | **Built-in** |

## Quick Start

```zig
const std = @import("std");
const nk = @import("naurikit");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var app = try nk.App.init(gpa.allocator(), .{ .name = "My App" });
    defer app.deinit();

    const win = try app.createWindow(.{
        .title = "Hello NauriKit",
        .width = 1024,
        .height = 768,
        .theme = .dark,
    });

    const wv = try win.createWebView(.{
        .html = @embedFile("ui/index.html"),
        .dev_tools = true,
    });

    // Register IPC command: JS → Zig
    try wv.onCommand("greet", nk.IpcCommand.make(greetHandler), null);

    win.show();
    _ = try app.run();
}

fn greetHandler(ctx: *nk.IpcContext, payload: std.json.Value) void {
    const name = payload.object.get("name").?.string;
    ctx.resolveValue("Hello, " ++ name ++ "! 👋");
}
```

```js
// In your HTML/JS:
const greeting = await naurikit.invoke("greet", { name: "World" });
console.log(greeting); // "Hello, World! 👋"
```

## Architecture

```
Your App (HTML/CSS/JS)
        │
        │  window.__naurikit.invoke("cmd", payload)
        ▼
  NauriKit JS Bridge  (injected, <2KB minified)
        │
        │  WebView2 / WebKitGTK postMessage
        ▼
  NauriKit IPC Layer  (Zig, zero-copy JSON dispatch)
        │
        │  handler(ctx, payload)
        ▼
  Your Zig Handler
        │
        │  ctx.resolveValue(result)
        ▼
  Back to JS Promise
```

## API Reference

### App
```zig
var app = try nk.App.init(allocator, .{ .name = "App", .single_instance = true });
const window = try app.createWindow(config);
const code = try app.run();
app.quit(0);
```

### Window
```zig
win.setTitle("New Title");
win.setSize(1280, 720);
win.center();
win.maximize(); win.minimize(); win.restore();
win.setTheme(.dark);
win.setAlwaysOnTop(true);
```

### WebView
```zig
try wv.navigate("https://example.com");
try wv.loadHtml("<h1>Hello</h1>");
try wv.eval("document.title = 'Hi'");
wv.reload();
wv.openDevTools();
```

### IPC
```zig
// Register handler
try wv.onCommand("my_cmd", nk.IpcCommand.make(handler), user_data_ptr);

// In handler:
fn handler(ctx: *nk.IpcContext, payload: std.json.Value) void {
    ctx.resolveValue(.{ .ok = true, .data = "result" });
    // or:
    ctx.rejectError("something went wrong: {}", .{err});
}
```

```js
// In JS:
const result = await naurikit.invoke("my_cmd", { key: "value" });
```

### Filesystem
```zig
const data = try nk.Fs.readFile(allocator, "config.json");
try nk.Fs.writeFile("output.txt", "hello");
const dir = try nk.Fs.appDataDir(allocator, "MyApp");
```

### Dialogs
```zig
const path = try nk.Dialog.openFile(allocator, "Open...", &.{
    .{ .name = "Text files", .pattern = "*.txt" },
});
```

### Notifications
```zig
nk.Notification.builder("Title")
    .withBody("Something happened!")
    .show();
```

## Building

```sh
# Prerequisites: Zig 0.16+, WebView2 Runtime (Windows)

# Build all
zig build

# Run the hello example
zig build run-hello

# Run tests
zig build test

# Release build (optimized + stripped)
zig build -Doptimize=ReleaseFast
```

## Platform Support

| Platform | Status | WebView Engine |
|---|---|---|
| Windows 10/11 | ✅ Phase 1 | WebView2 (Edge Chromium) |
| Linux (GTK) | 🚧 Phase 5 | WebKitGTK |
| macOS | 📅 Planned | WKWebView |
| Your OS | 📅 Future | Custom |

## Roadmap

- [x] Phase 1: Win32 window + WebView2 + IPC
- [ ] Phase 2: Dialogs, Tray icon, Notifications
- [ ] Phase 3: CLI tool (`naurikit new`, `naurikit dev`)
- [ ] Phase 4: Hot-reload in dev mode
- [ ] Phase 5: Linux GTK backend
- [ ] Phase 6: macOS WKWebView backend

---

**NauriKit** is part of the [Nauri](https://github.com/nauri) project.  
Built with ❤️ and Zig.
