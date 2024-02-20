const std = @import("std");
const FreezeStep = @This();

step: std.Build.Step,
freeze_program: std.Build.LazyPath,
source: std.Build.LazyPath,
output_file: std.Build.GeneratedFile,
name: []const u8,

pub fn create(b: *std.Build, freezeProgram: std.Build.LazyPath, source: std.Build.LazyPath, name: []const u8) *FreezeStep {
    const self = b.allocator.create(FreezeStep) catch @panic("OOM");
    self.* = .{
        .step = std.Build.Step.init(.{
            .id = .custom,
            .name = b.fmt("Generate {s}.h", .{name}),
            .owner = b,
            .makeFn = make,
        }),
        .freeze_program = freezeProgram,
        .output_file = .{ .step = &self.step },
        .name = name,
        .source = source,
    };

    freezeProgram.addStepDependencies(&self.step);
    return self;
}

fn make(step: *std.Build.Step, _: *std.Progress.Node) anyerror!void {
    const b = step.owner;
    const self = @fieldParentPtr(FreezeStep, "step", step);

    var man = b.graph.cache.obtain();
    defer man.deinit();

    _ = try man.addFile(self.freeze_program.getPath2(b, step), null);
    _ = try man.addFile(self.source.getPath2(b, step), null);

    if (try step.cacheHit(&man)) {
        const digest = man.final();
        self.output_file.path = try b.cache_root.join(b.allocator, &.{ "o", &digest, b.fmt("{s}.h", .{self.name}) });
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

    self.output_file.path = try b.cache_root.join(b.allocator, &.{ "o", &digest, b.fmt("{s}.h", .{self.name}) });

    if (std.mem.eql(u8, ".py", std.fs.path.extension(self.freeze_program.getPath2(b, step)))) {
        const cmd = try b.findProgram(&.{ "python3", "python" }, &.{});
        try step.evalChildProcess(&.{
            cmd,
            self.freeze_program.getPath2(b, step),
            self.name,
            self.source.getPath2(b, step),
            self.output_file.getPath(),
        });
    } else {
        try step.evalChildProcess(&.{
            self.freeze_program.getPath2(b, step),
            self.name,
            self.source.getPath2(b, step),
            self.output_file.getPath(),
        });
    }

    try step.writeManifest(&man);
}
