const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Web module for WASM bindings
    const web_module = b.createModule(.{
        .root_source_file = b.path("src/web.zig"),
    });

    // Components module
    const components_module = b.createModule(.{
        .root_source_file = b.path("src/components/mod.zig"),
        .imports = &.{
            .{ .name = "web", .module = web_module },
        },
    });

    // WASM target for web build
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    // WASM executable
    const wasm_exe = b.addExecutable(.{
        .name = "video-editor",
        .root_source_file = b.path("src/main.zig"),
        .target = wasm_target,
        .optimize = optimize,
    });

    wasm_exe.root_module.addImport("web", web_module);
    wasm_exe.root_module.addImport("components", components_module);
    wasm_exe.entry = .disabled;
    wasm_exe.rdynamic = true;

    // Install WASM binary
    b.installArtifact(wasm_exe);

    // Copy web assets
    const copy_web_step = b.step("copy-web", "Copy web assets");

    const copy_html = b.addInstallFile(b.path("src/web/index.html"), "web/index.html");
    const copy_js = b.addInstallFile(b.path("src/web/app.js"), "web/app.js");
    const copy_js2 = b.addInstallFile(b.path("src/web/bindings.js"), "web/bindings.js");
    const copy_js3 = b.addInstallFile(b.path("src/web/camera.js"), "web/camera.js");
    const copy_js4 = b.addInstallFile(b.path("src/web/editor.js"), "web/editor.js");
    const copy_js5 = b.addInstallFile(b.path("src/web/ui.js"), "web/ui.js");
    const copy_js6 = b.addInstallFile(b.path("src/web/video_editor.js"), "web/video_editor.js");
    const copy_css = b.addInstallFile(b.path("src/web/styles.css"), "web/styles.css");

    copy_web_step.dependOn(&copy_html.step);
    copy_web_step.dependOn(&copy_js.step);
    copy_web_step.dependOn(&copy_js2.step);
    copy_web_step.dependOn(&copy_js3.step);
    copy_web_step.dependOn(&copy_js4.step);
    copy_web_step.dependOn(&copy_js5.step);
    copy_web_step.dependOn(&copy_js6.step);
    copy_web_step.dependOn(&copy_css.step);

    // Web build step
    const web_step = b.step("web", "Build for web (WASM)");
    web_step.dependOn(b.getInstallStep());
    web_step.dependOn(copy_web_step);

    // Test step
    const tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    tests.root_module.addImport("web", web_module);
    tests.root_module.addImport("components", components_module);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // WASM-only build step (skip dev-server for now)
    const wasm_only_step = b.step("wasm", "Build WASM only (skip dev-server)");
    wasm_only_step.dependOn(b.getInstallStep());
    wasm_only_step.dependOn(copy_web_step);

    // Default to WASM-only build to avoid dev-server issues
    b.default_step = wasm_only_step;
}
