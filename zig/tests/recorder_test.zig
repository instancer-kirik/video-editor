const std = @import("std");
const testing = std.testing;
const components = @import("components");
const web = @import("mock_web");

pub fn testLogHandler(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = "(" ++ @tagName(scope) ++ "): ";
    const prefix = "[" ++ @tagName(level) ++ "] " ++ scope_prefix;

    // Print the message to stderr, silently ignoring any errors
    std.debug.getStderrMutex().lock();
    defer std.debug.getStderrMutex().unlock();
    const stderr = std.io.getStdErr().writer();
    stderr.print(prefix ++ format ++ "\n", args) catch return;
}

pub const std_options = struct {
    pub const log_level = .debug;
    pub const logFn = testLogHandler;
};

test "recorder initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const constraints = web.MediaConstraints{
        .video = .{
            .width = 640,
            .height = 480,
            .framerate = 30,
            .noiseSuppression = true,
        },
        .audio = .{
            .echoCancellation = true,
            .noiseSuppression = true,
        },
    };

    std.log.debug("Getting user media...", .{});
    const stream = try web.getUserMedia(&constraints);
    if (!stream) {
        std.log.err("Failed to get user media stream", .{});
        return error.StreamCreationFailed;
    }
    std.log.debug("Got user media stream", .{});

    std.log.debug("Creating recorder...", .{});
    const rec = try components.recorder.Recorder.init(allocator, stream);
    if (rec == null) {
        std.log.err("Failed to create recorder", .{});
        return error.RecorderCreationFailed;
    }
    std.log.debug("Created recorder successfully", .{});
    defer rec.deinit();

    try testing.expect(!rec.is_recording);
    try testing.expect(rec.stream != null);
    try testing.expect(rec.chunks.items.len == 0);
}

test "recorder start/stop cycle" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const constraints = web.MediaConstraints{
        .video = .{
            .width = 640,
            .height = 480,
            .framerate = 30,
            .noiseSuppression = true,
        },
        .audio = .{
            .echoCancellation = true,
            .noiseSuppression = true,
        },
    };

    std.log.debug("Getting user media for start/stop test...", .{});
    const stream = try web.getUserMedia(&constraints);
    std.log.debug("Creating recorder for start/stop test...", .{});
    const rec = try components.recorder.Recorder.init(allocator, stream);
    defer rec.deinit();

    std.log.debug("Starting recording...", .{});
    try rec.start();
    try testing.expect(rec.is_recording);
    try testing.expect(rec.stream != null);
    try testing.expect(rec.recorder_handle != null);

    std.log.debug("Stopping recording...", .{});
    try rec.stop();
    try testing.expect(!rec.is_recording);
}

const TestContext = struct {
    fn onData(data: []const u8) void {
        _ = data;
        test_received_data = true;
    }
};

var test_received_data: bool = false;

test "recording data handling" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const constraints = web.MediaConstraints{
        .video = .{
            .width = 640,
            .height = 480,
            .framerate = 30,
            .noiseSuppression = true,
        },
        .audio = .{
            .echoCancellation = true,
            .noiseSuppression = true,
        },
    };

    std.log.debug("Getting user media for data handling test...", .{});
    const stream = try web.getUserMedia(&constraints);
    std.log.debug("Creating recorder for data handling test...", .{});
    const rec = try components.recorder.Recorder.init(allocator, stream);
    defer rec.deinit();

    test_received_data = false;
    std.log.debug("Setting data callback...", .{});
    rec.setDataAvailableCallback(TestContext.onData);

    std.log.debug("Starting recording for data test...", .{});
    try rec.start();
    std.log.debug("Stopping recording for data test...", .{});
    try rec.stop();

    try testing.expect(test_received_data);
    try testing.expect(rec.chunks.items.len > 0);
}
