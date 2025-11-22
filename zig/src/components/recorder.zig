const std = @import("std");
const media = @import("media.zig");
const web = @import("web");
const ui = @import("ui.zig");

pub const Recorder = struct {
    stream: ?*web.MediaStreamHandle,
    is_recording: bool,
    mime_type: []const u8,
    allocator: std.mem.Allocator,
    chunks: std.ArrayList([]const u8),
    recorder_handle: ?*web.MediaRecorderHandle,
    on_data_available: ?*const fn ([]const u8) void,
    start_time: i64,
    preview_handle: ?*web.PreviewHandle,
    context: Context,

    const Context = struct {
        recorder: *Recorder,

        fn dataCallback(data: [*]const u8, len: usize) callconv(.C) void {
            if (current_context) |ctx| {
                const chunk = ctx.recorder.allocator.dupe(u8, data[0..len]) catch return;
                ctx.recorder.chunks.append(chunk) catch {
                    ctx.recorder.allocator.free(chunk);
                    return;
                };
                if (ctx.recorder.on_data_available) |callback| {
                    callback(chunk);
                }
            }
        }
    };

    var current_context: ?*Context = null;

    pub fn init(allocator: std.mem.Allocator, stream: *web.MediaStreamHandle) !*Recorder {
        const self = try allocator.create(Recorder);
        self.* = .{
            .stream = stream,
            .is_recording = false,
            .mime_type = "video/webm;codecs=vp8,opus",
            .allocator = allocator,
            .chunks = std.ArrayList([]const u8).init(allocator),
            .recorder_handle = null,
            .on_data_available = null,
            .start_time = 0,
            .preview_handle = null,
            .context = undefined,
        };

        self.context = .{ .recorder = self };
        current_context = &self.context;

        const options = web.MediaRecorderOptions{
            .mimeType = "video/webm",
            .videoBitsPerSecond = 2500000,
            .audioBitsPerSecond = 128000,
        };

        self.recorder_handle = web.createMediaRecorder(
            stream,
            &options,
            Context.dataCallback,
        );

        if (self.recorder_handle == null) {
            current_context = null;
            allocator.destroy(self);
            return error.MediaRecorderCreationFailed;
        }

        return self;
    }

    pub fn deinit(self: *Recorder) void {
        for (self.chunks.items) |chunk| {
            self.allocator.free(chunk);
        }
        self.chunks.deinit();
        if (self.stream) |stream| {
            web.deinitMediaStream(stream);
        }
        if (self.recorder_handle) |handle| {
            web.deinitMediaRecorder(handle);
        }
        if (self.preview_handle) |handle| {
            handle.deinit();
        }
        current_context = null;
        self.allocator.destroy(self);
    }

    pub fn start(self: *Recorder) !void {
        if (self.is_recording) return error.AlreadyRecording;

        if (self.recorder_handle) |handle| {
            web.startMediaRecorder(handle, 1000);
            self.start_time = std.time.milliTimestamp();
            self.is_recording = true;
        } else {
            return error.NoMediaRecorder;
        }
    }

    pub fn stop(self: *Recorder) !void {
        if (!self.is_recording) return;

        if (self.recorder_handle) |handle| {
            web.stopMediaRecorder(handle);
        }

        if (self.stream) |stream| {
            web.stopMediaStream(stream);
        }
        self.is_recording = false;
    }

    pub fn update(self: *Recorder) !void {
        if (self.is_recording) {
            try self.updatePreview();
        }
    }

    fn updatePreview(self: *Recorder) !void {
        if (self.preview_handle) |handle| {
            if (self.stream) |stream| {
                handle.setVideoSource(stream);
            }
        }
    }

    pub fn renderPreview(self: *Recorder, preview: *ui.Preview) !void {
        if (self.stream) |stream| {
            try preview.renderVideoFrame(stream);
        }
    }

    pub fn getRecordingDuration(self: *Recorder) i64 {
        if (!self.is_recording) return 0;
        return std.time.milliTimestamp() - self.start_time;
    }

    pub fn setPreviewHandle(self: *Recorder, handle: *web.PreviewHandle) void {
        if (self.preview_handle) |old_handle| {
            old_handle.deinit();
        }
        self.preview_handle = handle;
    }

    pub fn getChunks(self: *Recorder) []const []const u8 {
        return self.chunks.items;
    }

    pub fn clearChunks(self: *Recorder) void {
        for (self.chunks.items) |chunk| {
            self.allocator.free(chunk);
        }
        self.chunks.clearRetainingCapacity();
    }

    pub fn setDataAvailableCallback(self: *Recorder, callback: *const fn ([]const u8) void) void {
        self.on_data_available = callback;
    }
};
