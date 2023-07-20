const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Import libraries
    const opts = .{ .target = target, .optimize = optimize };
    const getty = b.dependency("getty", opts);
    const json = b.dependency("json", opts);
    const dotenv = b.dependency("dotenv", opts);

    const lib = b.addStaticLibrary(.{
        .name = "ethers-zig",
        .root_source_file = .{ .path = "src/provider.zig" },
        .target = target,
        .optimize = optimize,
    });

    lib.addModule("getty", getty.module("getty"));
    lib.addModule("json", json.module("json"));
    lib.addModule("dotenv", dotenv.module("dotenv"));

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/provider.zig" },
        .target = target,
        .optimize = optimize,
    });

    main_tests.addModule("getty", getty.module("getty"));
    main_tests.addModule("json", json.module("json"));
    main_tests.addModule("dotenv", dotenv.module("dotenv"));

    const run_main_tests = b.addRunArtifact(main_tests);

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build test`
    // This will evaluate the `test` step rather than the default, which is "install".
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}
