const std = @import("std");

pub const Value = *opaque {};

pub extern "env" fn getUserMedia() ?Value;
pub extern "env" fn getVideoTrack(stream: Value) ?Value;
pub extern "env" fn getAudioTrack(stream: Value) ?Value;
pub extern "env" fn createMediaRecorderInternal(stream: Value) ?Value;
pub extern "env" fn setDataAvailableCallback(callback: Value) Value;
pub extern "env" fn setErrorCallback(callback: Value) Value;

pub fn createMediaRecorder(stream: Value) !Value {
    if (createMediaRecorderInternal(stream)) |recorder| {
        return recorder;
    }
    return error.MediaRecorderCreationFailed;
}

pub fn getStream(camera: Value) ?Value {
    if (camera) |cam| {
        return cam;
    }
    return null;
}
