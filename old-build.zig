const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we set default to wasm32-wasi
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .wasm32,
            .os_tag = .wasi,
        },
    });

    // Standard optimization options
    const optimize = b.standardOptimizeOption(.{});

    // Create modules
    const web_module = b.createModule(.{
        .root_source_file = .{ .path = "src/components/web.zig" },
    });

    const components_module = b.createModule(.{
        .root_source_file = .{ .path = "src/components/mod.zig" },
        .imports = &.{
            .{ .name = "web", .module = web_module },
        },
    });

    // Main WASM executable
    const web_exe = b.addExecutable(.{
        .name = "video_editor",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    web_exe.root_module.addImport("components", components_module);
    web_exe.root_module.addImport("web", web_module);

    // Install the WASM binary
    b.installArtifact(web_exe);

    // Add tests
    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "tests/recorder_test.zig" },
        .target = target,
        .optimize = optimize,
    });

    main_tests.root_module.addImport("components", components_module);
    main_tests.root_module.addImport("web", web_module);

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    // Create a step to copy web files
    const copy_web_files = b.addSystemCommand(&[_][]const u8{
        "cp",
        "src/web/index.html",
        "src/web/bindings.js",
        "zig-out/web/",
    });

    const web_step = b.step("web", "Build and prepare web files");
    web_step.dependOn(&web_exe.step);
    web_step.dependOn(&copy_web_files.step);
}
