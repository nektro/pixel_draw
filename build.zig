const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    var target = b.standardTargetOptions(.{});
    // target.abi = .musl;

    const mode = b.standardReleaseOptions();
    const windows = b.option(bool, "windows", "create windows build") orelse false;
    const strip = b.option(bool, "strip", "strip debug info") orelse false;

    var exe = b.addExecutable("pixel_drawer", "src/main.zig");
    exe.setTarget(target);

    if (windows) {
        exe.setTarget(.{
            .cpu_arch = .x86_64,
            .os_tag = .windows,
            .abi = .gnu,
        });
    }

    exe.setBuildMode(mode);
    if (strip)
        exe.strip = true;

    if (@import("builtin").os.tag != .windows) {
        exe.linkSystemLibrary("X11");
    }

    exe.linkSystemLibrary("c");
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
