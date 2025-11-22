const std = @import("std");
const js = @import("js.zig");

pub const Camera = struct {
    stream_wrapper: ?js.Value,
    video_track: ?js.Value,
    audio_track: ?js.Value,

    pub fn init() !Camera {
        const stream_wrapper = js.getUserMedia() orelse return error.CameraInitFailed;
        const video_track = js.getVideoTrack(stream_wrapper);
        const audio_track = js.getAudioTrack(stream_wrapper);

        return Camera{
            .stream_wrapper = stream_wrapper,
            .video_track = video_track,
            .audio_track = audio_track,
        };
    }

    pub fn deinit(self: *Camera) void {
        if (self.video_track) |track| {
            track.stop();
        }
        if (self.audio_track) |track| {
            track.stop();
        }
    }

    pub fn getStream(self: *const Camera) ?js.Value {
        if (self.stream_wrapper) |wrapper| {
            return js.getStream(wrapper);
        }
        return null;
    }

    pub fn getVideoTrack(self: *const Camera) ?js.Value {
        return self.video_track;
    }

    pub fn getAudioTrack(self: *const Camera) ?js.Value {
        return self.audio_track;
    }
};
