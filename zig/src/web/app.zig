const std = @import("std");
const js = @import("js.zig");
const ui = @import("ui.zig");
const Camera = @import("camera.zig").Camera;

pub const VideoApp = struct {
    camera: Camera,
    ui: ui.UI,
    is_recording: bool = false,
    media_recorder: ?js.Value = null,

    pub fn init() !VideoApp {
        const camera = try Camera.init();
        const ui_instance = try ui.UI.init();

        return VideoApp{
            .camera = camera,
            .ui = ui_instance,
        };
    }

    pub fn deinit(self: *VideoApp) void {
        self.camera.deinit();
        self.ui.deinit();
    }

    pub fn startRecording(self: *VideoApp) !void {
        if (self.is_recording) return;

        const stream = self.camera.getStream() orelse return error.NoStreamAvailable;
        self.media_recorder = try js.createMediaRecorder(stream);
        self.is_recording = true;

        if (self.media_recorder) |recorder| {
            recorder.start();
            try self.ui.updateRecordingState(true);
        }
    }

    pub fn stopRecording(self: *VideoApp) !void {
        if (!self.is_recording) return;

        if (self.media_recorder) |recorder| {
            recorder.stop();
            self.is_recording = false;
            try self.ui.updateRecordingState(false);
        }
    }

    // ... rest of VideoApp implementation
};
