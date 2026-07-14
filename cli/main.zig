//! cli/main.zig — NauriKit CLI tool
//!
//! Usage:
//!   naurikit new <project-name> [--template basic|react]
//!   naurikit dev [--port 1420]
//!   naurikit build [--release]
//!   naurikit version

const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const cmd = args[1];

    if (std.mem.eql(u8, cmd, "new")) {
        try cmdNew(allocator, args[2..]);
    } else if (std.mem.eql(u8, cmd, "dev")) {
        try cmdDev(allocator, args[2..]);
    } else if (std.mem.eql(u8, cmd, "build")) {
        try cmdBuild(allocator, args[2..]);
    } else if (std.mem.eql(u8, cmd, "version") or std.mem.eql(u8, cmd, "--version") or std.mem.eql(u8, cmd, "-v")) {
        try cmdVersion();
    } else if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "--help") or std.mem.eql(u8, cmd, "-h")) {
        printUsage();
    } else {
        std.log.err("Unknown command: {s}", .{cmd});
        printUsage();
        std.process.exit(1);
    }
}

fn printUsage() void {
    const stdout = std.io.getStdOut().writer();
    stdout.print(
        \\NauriKit CLI — Ultra-lightweight desktop app framework
        \\
        \\USAGE:
        \\  naurikit <command> [options]
        \\
        \\COMMANDS:
        \\  new <name> [--template basic|react]   Create a new project
        \\  dev [--port 1420]                     Run dev server with hot-reload
        \\  build [--release]                      Build the project
        \\  version                               Print version info
        \\  help                                   Show this help
        \\
        \\EXAMPLES:
        \\  naurikit new myapp
        \\  naurikit new myapp --template react
        \\  naurikit dev --port 3000
        \\  naurikit build --release
        \\
    , .{}) catch {};
}

fn cmdNew(allocator: std.mem.Allocator, args: []const []u8) !void {
    if (args.len < 1) {
        std.log.err("Usage: naurikit new <name> [--template basic|react]", .{});
        std.process.exit(1);
    }

    const project_name = args[0];
    var template: []const u8 = "basic";

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--template") and i + 1 < args.len) {
            template = args[i + 1];
            i += 1;
        }
    }

    const cwd = std.fs.cwd();
    const project_dir = project_name;

    // Check if directory exists
    if (cwd.access(project_dir, .{}) catch null) != null) {
        std.log.err("Directory '{s}' already exists", .{project_dir});
        std.process.exit(1);
    }

    try cwd.makePath(project_dir);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Creating project '{s}' (template: {s})...\n", .{ project_name, template });

    // Create build.zig
    try createFile(cwd, project_dir, "build.zig", try generateBuildZig(allocator, project_name));

    // Create build.zig.zon
    try createFile(cwd, project_dir, "build.zig.zon", try generateBuildZon(allocator, project_name));

    // Create src/main.zig
    try cwd.makePath(try std.fmt.allocPrint(allocator, "{s}/src", .{project_dir}));
    try createFile(cwd, project_dir, "src/main.zig", try generateMainZig(allocator, project_name));

    // Create src/index.html
    try createFile(cwd, project_dir, "src/index.html", try generateIndexHtml(allocator, project_name));

    // Create .gitignore
    try createFile(cwd, project_dir, ".gitignore",
        \\zig-cache/
        \\zig-out/
        \\node_modules/
        \\dist/
        \\*.exe
        \\*.pdb
        \\
    );

    try stdout.print("✓ Project created!\n", .{});
    try stdout.print("Next steps:\n", .{});
    try stdout.print("  cd {s}\n", .{project_dir});
    try stdout.print("  naurikit dev\n", .{});
}

fn cmdDev(allocator: std.mem.Allocator, args: []const []u8) !void {
    _ = args;

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Starting dev server...\n", .{});

    // Run zig build run-hello or just zig build run
    var child = std.process.Child.init(.{
        .argv = &.{ "zig", "build", "run" },
        .cwd = ".",
    }, allocator);
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    try child.spawn();
    const term = try child.wait();
    switch (term) {
        .Exited => |code| std.process.exit(code),
        else => std.process.exit(1),
    }
}

fn cmdBuild(allocator: std.mem.Allocator, args: []const []u8) !void {
    var release = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--release")) release = true;
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Building ({s})...\n", .{if (release) "release" else "debug"});

    var argv = std.ArrayList([]const u8).empty;
    defer argv.deinit(allocator);
    try argv.append(allocator, "zig");
    try argv.append(allocator, "build");
    if (release) {
        try argv.append(allocator, "-Doptimize=ReleaseFast");
    }

    var child = std.process.Child.init(.{
        .argv = argv.items,
        .cwd = ".",
    }, allocator);
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    try child.spawn();
    const term = try child.wait();
    switch (term) {
        .Exited => |code| {
            if (code == 0) {
                try stdout.print("✓ Build complete!\n", .{});
            } else {
                std.log.err("Build failed with code {d}", .{code});
            }
            std.process.exit(code);
        },
        else => std.process.exit(1),
    }
}

fn cmdVersion() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("NauriKit 0.1.0\n", .{});
    try stdout.print("Zig {s}\n", .{@import("builtin").zig_version_string});
}

// ─── Template generators ─────────────────────────────────────────────────────

fn createFile(cwd: std.fs.Dir, dir: []const u8, name: []const u8, content: []const u8) !void {
    const path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/{s}", .{ dir, name });
    defer std.heap.page_allocator.free(path);
    var file = try cwd.createFile(path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(content);
}

fn generateBuildZig(allocator: std.mem.Allocator, project_name: []const u8) ![]u8 {
    _ = project_name;
    return try allocator.dupe(u8,
        \\const std = @import("std");
        \\
        \\pub fn build(b: *std.Build) void {
        \\    const target = b.standardTargetOptions(.{});
        \\    const optimize = b.standardOptimizeOption(.{});
        \\
        \\    const naurikit_dep = b.dependency("naurikit", .{
        \\        .target = target,
        \\        .optimize = optimize,
        \\    });
        \\    const naurikit_mod = naurikit_dep.module("naurikit");
        \\
        \\    const mod = b.createModule(.{
        \\        .root_source_file = b.path("src/main.zig"),
        \\        .target = target,
        \\        .optimize = optimize,
        \\        .imports = &.{
        \\            .{ .name = "naurikit", .module = naurikit_mod },
        \\        },
        \\    });
        \\
        \\    const exe = b.addExecutable(.{
        \\        .name = "app",
        \\        .root_module = mod,
        \\    });
        \\    b.installArtifact(exe);
        \\
        \\    const run_cmd = b.addRunArtifact(exe);
        \\    const run_step = b.step("run", "Run the app");
        \\    run_step.dependOn(&run_cmd.step);
        \\}
        \\
    );
}

fn generateBuildZon(allocator: std.mem.Allocator, project_name: []const u8) ![]u8 {
    return try std.fmt.allocPrint(allocator,
        \\.{{
        \\    .name = .{s},
        \\    .fingerprint = 0x{x:0>16},
        \\    .version = "0.1.0",
        \\    .minimum_zig_version = "0.16.0-dev.1",
        \\    .dependencies = .{{
        \\        .naurikit = .{{
        \\            .url = "https://github.com/artembabenko259-ai/NauriKit/archive/main.tar.gz",
        \\        }},
        \\    }},
        \\    .paths = .{{
        \\        "src",
        \\        "build.zig",
        \\        "build.zig.zon",
        \\    }},
        \\}}
        \\
    , .{ project_name, std.hash.int(@intFromPtr(project_name.ptr)) });
}

fn generateMainZig(allocator: std.mem.Allocator, project_name: []const u8) ![]u8 {
    _ = project_name;
    return try allocator.dupe(u8,
        \\const std = @import("std");
        \\const nk = @import("naurikit");
        \\
        \\pub fn main() !void {
        \\    var gpa = std.heap.DebugAllocator(.{}){};
        \\    defer _ = gpa.deinit();
        \\
        \\    var app = try nk.App.init(gpa.allocator(), .{
        \\        .name = "My App",
        \\    });
        \\    defer app.deinit();
        \\
        \\    const window = try app.createWindow(.{
        \\        .title = "My App",
        \\        .width = 1024,
        \\        .height = 768,
        \\        .center = true,
        \\        .theme = .dark,
        \\    });
        \\
        \\    const webview = try window.createWebView(.{
        \\        .html = @embedFile("index.html"),
        \\        .dev_tools = true,
        \\    });
        \\
        \\    try webview.onCommand("ping", nk.IpcCommand.make(struct {
        \\        fn h(ctx: *nk.IpcContext, _: std.json.Value) void {
        \\            ctx.resolveValue("pong");
        \\        }
        \\    }.h), null);
        \\
        \\    window.show();
        \\    _ = try app.run();
        \\}
        \\
    );
}

fn generateIndexHtml(allocator: std.mem.Allocator, project_name: []const u8) ![]u8 {
    return try std.fmt.allocPrint(allocator,
        \\<!DOCTYPE html>
        \\<html lang="en">
        \\<head>
        \\  <meta charset="UTF-8">
        \\  <meta name="viewport" content="width=device-width, initial-scale=1.0">
        \\  <title>{s}</title>
        \\  <style>
        \\    * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        \\    body {{
        \\      font-family: 'Inter', -apple-system, sans-serif;
        \\      background: #0a0a0a;
        \\      color: #ededed;
        \\      display: flex;
        \\      align-items: center;
        \\      justify-content: center;
        \\      height: 100vh;
        \\      -webkit-font-smoothing: antialiased;
        \\    }}
        \\    h1 {{ font-size: 28px; font-weight: 600; margin-bottom: 8px; }}
        \\    p {{ color: #888; font-size: 14px; margin-bottom: 24px; }}
        \\    button {{
        \\      background: #3b82f6;
        \\      color: white;
        \\      border: none;
        \\      padding: 10px 24px;
        \\      border-radius: 8px;
        \\      font-size: 14px;
        \\      cursor: pointer;
        \\    }}
        \\    button:hover {{ background: #2563eb; }}
        \\    #result {{ margin-top: 16px; font-family: monospace; color: #22c55e; }}
        \\  </style>
        \\</head>
        \\<body>
        \\  <div>
        \\    <h1>{s} ⚡</h1>
        \\    <p>Built with NauriKit + Zig</p>
        \\    <button onclick="ping()">Ping Zig backend</button>
        \\    <div id="result"></div>
        \\  </div>
        \\  <script>
        \\    async function ping() {{
        \\      const result = await naurikit.invoke('ping');
        \\      document.getElementById('result').textContent = 'Zig says: ' + result;
        \\    }}
        \\  </script>
        \\</body>
        \\</html>
        \\
    , .{ project_name, project_name });
}
