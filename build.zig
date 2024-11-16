const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(std.builtin.LinkMode, "linkage", "Specify static or dynamic linkage") orelse .dynamic;
    const upstream = b.dependency("libstatistics_collector", .{});

    const dependency_options = .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
    };

    var lib = std.Build.Step.Compile.create(b, .{
        .root_module = .{
            .target = target,
            .optimize = optimize,
            .pic = if (linkage == .dynamic) true else null,
        },
        .name = "libstatistics_collector",
        .kind = .lib,
        .linkage = linkage,
    });

    lib.linkLibCpp();
    lib.addIncludePath(upstream.path("include"));
    lib.installHeadersDirectory(
        upstream.path("include"),
        "",
        .{ .include_extensions = &.{ ".h", ".hpp" } },
    );

    const rcl_dep = b.dependency("rcl", dependency_options);
    const rcutils_dep = b.dependency("rcutils", dependency_options);

    // Grabbing dependencies out of rcl instead of specifying them again avoids rebuilding dependencies as long as same build args are used.
    // TODO I can't actually seem to confirm if this is true or not honestly
    const rcl_interfaces_dep = b.dependency("rcl_interfaces", dependency_options);

    const rosidl_dep = b.dependency("rosidl", dependency_options);
    const rcpputils_dep = b.dependency("rcpputils", dependency_options);

    // Note rcl covers all other dependencies so they are not explicitly added
    // This avoids rebuilding duplicate libraries and introducing version miss matches
    lib.linkLibrary(rcl_dep.artifact("rcl"));
    lib.linkLibrary(rcutils_dep.artifact("rcutils"));
    lib.linkLibrary(rcpputils_dep.artifact("rcpputils"));
    // TODO some rosidl helper for this?
    lib.addIncludePath(rcl_interfaces_dep.namedWriteFiles(
        "builtin_interfaces__rosidl_generator_cpp",
    ).getDirectory());
    lib.addIncludePath(rcl_interfaces_dep.namedWriteFiles(
        "statistics_msgs__rosidl_generator_cpp",
    ).getDirectory());

    lib.linkLibrary(rosidl_dep.artifact("rosidl_runtime_c"));
    lib.addIncludePath(rosidl_dep.namedWriteFiles("rosidl_runtime_cpp").getDirectory());
    lib.addIncludePath(rosidl_dep.namedWriteFiles("rosidl_typesupport_interface").getDirectory());

    lib.addCSourceFiles(.{
        .root = upstream.path("src"),
        .files = &.{
            "libstatistics_collector/collector/collector.cpp",
            "libstatistics_collector/collector/generate_statistics_message.cpp",
            "libstatistics_collector/moving_average_statistics/moving_average.cpp",
            "libstatistics_collector/moving_average_statistics/types.cpp",
        },
        .flags = &.{
            "-std=c++17",
            "-Wno-deprecated-declarations",
            "-DLIBSTATISTICS_COLLECTOR_BUILDING_LIBRARY",
            // "-fvisibility=hidden",  // TODO visibility hidden breaks this package
            // "-fvisibility-inlines-hidden",
        },
    });

    b.installArtifact(lib);
}
