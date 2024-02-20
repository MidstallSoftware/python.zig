const std = @import("std");
const DeepfreezeStep = @This();

step: std.Build.Step,
modules: std.StringHashMapUnmanaged(std.Build.LazyPath),
deepfreeze_program: std.Build.LazyPath,
output_file: std.Build.GeneratedFile,

pub fn create(b: *std.Build, deepfreezeProgram: std.Build.LazyPath) *DeepfreezeStep {
    const self = b.allocator.create(DeepfreezeStep) catch @panic("OOM");
    self.* = .{
        .step = std.Build.Step.init(.{
            .id = .custom,
            .name = "Generate deepfreeze.c",
            .owner = b,
            .makeFn = make,
        }),
        .deepfreeze_program = deepfreezeProgram,
        .modules = .{},
        .output_file = .{ .step = &self.step },
    };

    deepfreezeProgram.addStepDependencies(&self.step);
    return self;
}

pub fn addModule(self: *DeepfreezeStep, source: std.Build.LazyPath, name: []const u8) void {
    const b = self.step.owner;
    self.modules.put(b.allocator, name, source) catch @panic("OOM");
    source.addStepDependencies(&self.step);
}

fn make(step: *std.Build.Step, _: *std.Progress.Node) anyerror!void {
    const b = step.owner;
    const self = @fieldParentPtr(DeepfreezeStep, "step", step);

    var man = b.graph.cache.obtain();
    defer man.deinit();

    const cmd = try b.findProgram(&.{ "python3", "python" }, &.{});

    _ = try man.addFile(self.deepfreeze_program.getPath2(b, step), null);

    {
        var iter = self.modules.iterator();
        while (iter.next()) |module| {
            _ = try man.addFile(module.value_ptr.getPath2(b, step), null);
        }
    }

    if (try step.cacheHit(&man)) {
        const digest = man.final();
        self.output_file.path = try b.cache_root.join(b.allocator, &.{ "o", &digest, "deepfreeze.c" });
        return;
    }

    const digest = man.final();
    const cache_path = "o" ++ std.fs.path.sep_str ++ digest;

    var cache_dir = b.cache_root.handle.makeOpenPath(cache_path, .{}) catch |err| {
        return step.fail("unable to make path  = 1,{}{s} = 1,: {s}", .{
            b.cache_root, cache_path, @errorName(err),
        });
    };
    defer cache_dir.close();
    self.output_file.path = try b.cache_root.join(b.allocator, &.{ "o", &digest, "deepfreeze.c" });

    var args = std.ArrayList([]const u8).init(b.allocator);
    defer args.deinit();

    try args.appendSlice(&.{
        cmd,
        self.deepfreeze_program.getPath2(b, step),
    });

    {
        var iter = self.modules.iterator();
        while (iter.next()) |module| {
            try args.append(b.fmt("{s}:{s}", .{ module.value_ptr.getPath2(b, step), module.key_ptr.* }));
        }
    }

    try args.appendSlice(&.{
        "-o",
        self.output_file.path.?,
    });

    try step.evalChildProcess(try args.toOwnedSlice());
    try step.writeManifest(&man);
}
