const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ─── NauriKit module ─────────────────────────────────────────────────────
    const naurikit_mod = b.addModule("naurikit", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    linkModule(naurikit_mod, target);

    // ─── Static library ──────────────────────────────────────────────────────
    const lib = b.addLibrary(.{
        .name = "naurikit",
        .root_module = naurikit_mod,
        .linkage = .static,
    });
    b.installArtifact(lib);

    // ─── Example: hello ──────────────────────────────────────────────────────
    const hello_mod = b.createModule(.{
        .root_source_file = b.path("examples/hello/src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "naurikit", .module = naurikit_mod },
        },
    });
    linkModule(hello_mod, target);

    const hello_exe = b.addExecutable(.{
        .name = "hello",
        .root_module = hello_mod,
    });
    b.installArtifact(hello_exe);

    const run_hello = b.addRunArtifact(hello_exe);
    const run_step = b.step("run-hello", "Run the hello example");
    run_step.dependOn(&run_hello.step);

    // ─── Example: react-app ──────────────────────────────────────────────────
    const react_mod = b.createModule(.{
        .root_source_file = b.path("examples/react-app/src-nauri/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "naurikit", .module = naurikit_mod },
        },
    });
    linkModule(react_mod, target);

    const react_exe = b.addExecutable(.{
        .name = "react-app",
        .root_module = react_mod,
    });
    if (optimize == .ReleaseFast or optimize == .ReleaseSmall) {
        react_exe.subsystem = .Windows;
    }
    b.installArtifact(react_exe);

    const run_react = b.addRunArtifact(react_exe);
    const run_react_step = b.step("run-react", "Run the react-app example");
    run_react_step.dependOn(&run_react.step);

    // ─── Tests ───────────────────────────────────────────────────────────────
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    linkModule(test_mod, target);

    const unit_tests = b.addTest(.{
        .root_module = test_mod,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

fn linkModule(module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    const t = target.result;
    if (t.os.tag == .windows) {
        module.linkSystemLibrary("user32", .{});
        module.linkSystemLibrary("gdi32", .{});
        module.linkSystemLibrary("ole32", .{});
        module.linkSystemLibrary("shell32", .{});
        module.linkSystemLibrary("oleaut32", .{});
        module.linkSystemLibrary("advapi32", .{});
        module.linkSystemLibrary("shlwapi", .{});
        module.linkSystemLibrary("dwmapi", .{});
        module.link_libc = true;
    } else if (t.os.tag == .linux) {
        module.linkSystemLibrary("gtk-3", .{});
        module.linkSystemLibrary("webkit2gtk-4.0", .{});
        module.link_libc = true;
    }
}
