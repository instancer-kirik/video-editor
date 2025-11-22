const std = @import("std");
const web = @import("web");
const log = std.log.scoped(.media); // Create a scoped logger for media module

pub const MediaStream = struct {
    allocator: std.mem.Allocator,
    stream_handle: ?*web.MediaStreamHandle,
    video_track: ?*web.MediaTrackHandle,
    audio_track: ?*web.MediaTrackHandle,

    pub fn init(allocator: std.mem.Allocator) !*MediaStream {
        const self = try allocator.create(MediaStream);
        self.* = .{
            .allocator = allocator,
            .stream_handle = null,
            .video_track = null,
            .audio_track = null,
        };
        return self;
    }

    pub fn deinit(self: *MediaStream) void {
        if (self.stream_handle) |handle| {
            web.deinitMediaStream(handle);
        }
        self.allocator.destroy(self);
    }

    pub fn startCapture(self: *MediaStream, options: web.StreamOptions) !void {
        if (self.stream_handle != null) {
            return error.StreamAlreadyActive;
        }

        const constraints = web.MediaConstraints{
            .video = .{
                .width = options.video.width,
                .height = options.video.height,
                .framerate = options.video.frameRate,
            },
            .audio = .{
                .echoCancellation = options.audio.echoCancellation,
                .noiseSuppression = options.audio.noiseSuppression,
            },
        };

        self.stream_handle = try web.getUserMedia(&constraints);
        if (self.stream_handle) |handle| {
            self.video_track = handle.getVideoTrack();
            self.audio_track = handle.getAudioTrack();
        }
    }

    pub fn stopCapture(self: *MediaStream) void {
        if (self.stream_handle) |handle| {
            web.stopMediaStream(handle);
            self.stream_handle = null;
            self.video_track = null;
            self.audio_track = null;
        }
    }

    pub fn getVideoTrack(self: *MediaStream) ?*web.MediaTrackHandle {
        return self.video_track;
    }

    pub fn getAudioTrack(self: *MediaStream) ?*web.MediaTrackHandle {
        return self.audio_track;
    }

    pub fn enableVideo(self: *MediaStream) void {
        if (self.video_track) |track| {
            track.enable();
        }
    }

    pub fn disableVideo(self: *MediaStream) void {
        if (self.video_track) |track| {
            track.disable();
        }
    }

    pub fn enableAudio(self: *MediaStream) void {
        if (self.audio_track) |track| {
            track.enable();
        }
    }

    pub fn disableAudio(self: *MediaStream) void {
        if (self.audio_track) |track| {
            track.disable();
        }
    }

    pub fn isActive(self: *MediaStream) bool {
        return self.stream_handle != null;
    }
};

pub const VideoTrack = struct {
    allocator: std.mem.Allocator,
    is_active: bool,
    track_handle: *web.MediaTrackHandle,

    pub fn init(allocator: std.mem.Allocator, track_handle: *web.MediaTrackHandle) !*VideoTrack {
        const self = try allocator.create(VideoTrack);
        self.* = .{
            .allocator = allocator,
            .is_active = false,
            .track_handle = track_handle,
        };
        return self;
    }

    pub fn deinit(self: *VideoTrack) void {
        self.track_handle.deinit();
        self.allocator.destroy(self);
    }

    pub fn start(self: *VideoTrack) !void {
        try self.track_handle.enable();
        self.is_active = true;
    }

    pub fn stop(self: *VideoTrack) void {
        self.track_handle.disable();
        self.is_active = false;
    }
};

pub const AudioTrack = struct {
    allocator: std.mem.Allocator,
    is_active: bool,
    track_handle: *web.MediaTrackHandle,

    pub fn init(allocator: std.mem.Allocator, track_handle: *web.MediaTrackHandle) !*AudioTrack {
        const self = try allocator.create(AudioTrack);
        self.* = .{
            .allocator = allocator,
            .is_active = false,
            .track_handle = track_handle,
        };
        return self;
    }

    pub fn deinit(self: *AudioTrack) void {
        self.track_handle.deinit();
        self.allocator.destroy(self);
    }

    pub fn start(self: *AudioTrack) !void {
        try self.track_handle.enable();
        self.is_active = true;
    }

    pub fn stop(self: *AudioTrack) void {
        self.track_handle.disable();
        self.is_active = false;
    }
};
