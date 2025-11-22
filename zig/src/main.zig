// WASM-compatible video editor main module
// This module provides the core exports for JavaScript interop

// Basic memory management for WASM
var memory: [1024 * 1024]u8 = undefined; // 1MB static buffer
var memory_offset: usize = 0;

// Simple allocator that uses static buffer
fn simple_alloc(size: usize) ?[*]u8 {
    if (memory_offset + size > memory.len) return null;
    const ptr: [*]u8 = @ptrCast(&memory[memory_offset]);
    memory_offset += size;
    return ptr;
}

// Error handling
var last_error: [256]u8 = undefined;
var error_len: usize = 0;

fn set_error(msg: []const u8) void {
    const len = if (msg.len < 255) msg.len else 255;
    for (0..len) |i| {
        last_error[i] = msg[i];
    }
    last_error[len] = 0;
    error_len = len;
}

// Core video editor state
const VideoEditorState = struct {
    is_recording: bool = false,
    frame_width: u32 = 1280,
    frame_height: u32 = 720,
    frame_rate: u32 = 30,
    current_filter: u32 = 0,
    brightness: f32 = 1.0,
    contrast: f32 = 1.0,
    saturation: f32 = 1.0,
};

var editor_state = VideoEditorState{};

// JavaScript interop exports
export fn init_video_editor() void {
    memory_offset = 0;
    editor_state = VideoEditorState{};
    set_error("Video editor initialized");
}

export fn start_recording() i32 {
    if (editor_state.is_recording) {
        set_error("Already recording");
        return -1;
    }
    editor_state.is_recording = true;
    set_error("Recording started");
    return 0;
}

export fn stop_recording() i32 {
    if (!editor_state.is_recording) {
        set_error("Not recording");
        return -1;
    }
    editor_state.is_recording = false;
    set_error("Recording stopped");
    return 0;
}

export fn is_recording() i32 {
    return if (editor_state.is_recording) 1 else 0;
}

export fn set_resolution(width: u32, height: u32) void {
    editor_state.frame_width = width;
    editor_state.frame_height = height;
}

export fn get_width() u32 {
    return editor_state.frame_width;
}

export fn get_height() u32 {
    return editor_state.frame_height;
}

export fn set_frame_rate(fps: u32) void {
    editor_state.frame_rate = fps;
}

export fn get_frame_rate() u32 {
    return editor_state.frame_rate;
}

// Video filters
export fn apply_brightness(value: f32) void {
    editor_state.brightness = value;
}

export fn apply_contrast(value: f32) void {
    editor_state.contrast = value;
}

export fn apply_saturation(value: f32) void {
    editor_state.saturation = value;
}

export fn get_brightness() f32 {
    return editor_state.brightness;
}

export fn get_contrast() f32 {
    return editor_state.contrast;
}

export fn get_saturation() f32 {
    return editor_state.saturation;
}

// Filter processing (simplified)
export fn process_frame(data_ptr: [*]u8, width: u32, height: u32) void {
    const pixel_count = width * height * 4; // RGBA

    var i: usize = 0;
    while (i < pixel_count) : (i += 4) {
        // Apply brightness
        const r = @as(f32, @floatFromInt(data_ptr[i])) * editor_state.brightness;
        const g = @as(f32, @floatFromInt(data_ptr[i + 1])) * editor_state.brightness;
        const b = @as(f32, @floatFromInt(data_ptr[i + 2])) * editor_state.brightness;

        // Clamp values
        data_ptr[i] = @intFromFloat(@max(0, @min(255, r)));
        data_ptr[i + 1] = @intFromFloat(@max(0, @min(255, g)));
        data_ptr[i + 2] = @intFromFloat(@max(0, @min(255, b)));
        // Alpha channel unchanged
    }
}

// Memory management exports
export fn alloc(size: usize) ?[*]u8 {
    return simple_alloc(size);
}

export fn reset_memory() void {
    memory_offset = 0;
}

export fn get_memory_usage() usize {
    return memory_offset;
}

export fn get_memory_capacity() usize {
    return memory.len;
}

// Error handling exports
export fn get_last_error() [*]const u8 {
    return &last_error;
}

export fn get_last_error_len() usize {
    return error_len;
}

// Text overlay support
const TextOverlay = struct {
    x: f32,
    y: f32,
    text: [128]u8,
    text_len: usize,
    font_size: u32,
    color: u32, // RGBA as u32
};

var text_overlays: [16]TextOverlay = undefined;
var text_overlay_count: usize = 0;

export fn add_text_overlay(x: f32, y: f32, text_ptr: [*]const u8, text_len: usize, font_size: u32, color: u32) i32 {
    if (text_overlay_count >= text_overlays.len) {
        set_error("Too many text overlays");
        return -1;
    }

    const len = if (text_len < 127) text_len else 127;
    var overlay = &text_overlays[text_overlay_count];
    overlay.x = x;
    overlay.y = y;
    overlay.font_size = font_size;
    overlay.color = color;
    overlay.text_len = len;

    for (0..len) |i| {
        overlay.text[i] = text_ptr[i];
    }
    overlay.text[len] = 0;

    text_overlay_count += 1;
    return @intCast(text_overlay_count - 1);
}

export fn remove_text_overlay(index: usize) i32 {
    if (index >= text_overlay_count) {
        set_error("Invalid text overlay index");
        return -1;
    }

    // Shift overlays down
    for (index..text_overlay_count - 1) |i| {
        text_overlays[i] = text_overlays[i + 1];
    }
    text_overlay_count -= 1;
    return 0;
}

export fn clear_text_overlays() void {
    text_overlay_count = 0;
}

export fn get_text_overlay_count() usize {
    return text_overlay_count;
}

// Timeline/trimming support
var timeline_start: f32 = 0.0;
var timeline_end: f32 = 10.0; // 10 seconds default
var current_time: f32 = 0.0;

// Clip management
const Clip = struct {
    id: u32,
    start_time: f32,
    duration: f32,
    name: [64]u8,
    name_len: usize,
    clip_type: u8, // 0=camera, 1=recording, 2=imported
};

var clips: [32]Clip = undefined;
var clip_count: usize = 0;
var next_clip_id: u32 = 1;

export fn set_timeline_range(start: f32, end: f32) void {
    timeline_start = start;
    timeline_end = end;
}

export fn get_timeline_start() f32 {
    return timeline_start;
}

export fn get_timeline_end() f32 {
    return timeline_end;
}

export fn set_current_time(time: f32) void {
    current_time = if (time >= timeline_start and time <= timeline_end) time else timeline_start;
}

export fn get_current_time() f32 {
    return current_time;
}

// Simple math utilities for JS
export fn add(a: i32, b: i32) i32 {
    return a + b;
}

export fn multiply(a: f32, b: f32) f32 {
    return a * b;
}

export fn clamp_f32(value: f32, min_val: f32, max_val: f32) f32 {
    return @max(min_val, @min(max_val, value));
}

// Test functions
export fn test_basic_math() i32 {
    return add(5, 3);
}

export fn test_memory() i32 {
    const ptr = alloc(100);
    return if (ptr != null) 1 else 0;
}

export fn test_video_state() i32 {
    init_video_editor();
    _ = start_recording();
    const recording = is_recording();
    _ = stop_recording();
    return recording;
}

// Version info
export fn get_version_major() u32 {
    return 0;
}

export fn get_version_minor() u32 {
    return 1;
}

export fn get_version_patch() u32 {
    return 0;
}

// Clip management exports
export fn add_clip(start_time: f32, duration: f32, name_ptr: [*]const u8, name_len: usize, clip_type: u8) u32 {
    if (clip_count >= clips.len) {
        set_error("Maximum number of clips reached");
        return 0;
    }

    var clip = &clips[clip_count];
    clip.id = next_clip_id;
    clip.start_time = start_time;
    clip.duration = duration;
    clip.clip_type = clip_type;

    const len = if (name_len < 63) name_len else 63;
    for (0..len) |i| {
        clip.name[i] = name_ptr[i];
    }
    clip.name[len] = 0;
    clip.name_len = len;

    clip_count += 1;
    next_clip_id += 1;

    return clip.id;
}

export fn remove_clip(clip_id: u32) i32 {
    for (0..clip_count) |i| {
        if (clips[i].id == clip_id) {
            // Shift clips down
            for (i..clip_count - 1) |j| {
                clips[j] = clips[j + 1];
            }
            clip_count -= 1;
            return 0;
        }
    }
    set_error("Clip not found");
    return -1;
}

export fn get_clip_count() usize {
    return clip_count;
}

export fn get_clip_info(index: usize, info_ptr: [*]u8) i32 {
    if (index >= clip_count) {
        set_error("Clip index out of range");
        return -1;
    }

    const clip = &clips[index];

    // Pack clip info into bytes: id(4) + start_time(4) + duration(4) + type(1) + name_len(1) + name(variable)
    const id_bytes: [4]u8 = @bitCast(clip.id);
    const start_bytes: [4]u8 = @bitCast(clip.start_time);
    const duration_bytes: [4]u8 = @bitCast(clip.duration);

    var offset: usize = 0;

    // Copy data
    for (0..4) |i| {
        info_ptr[offset + i] = id_bytes[i];
    }
    offset += 4;

    for (0..4) |i| {
        info_ptr[offset + i] = start_bytes[i];
    }
    offset += 4;

    for (0..4) |i| {
        info_ptr[offset + i] = duration_bytes[i];
    }
    offset += 4;

    info_ptr[offset] = clip.clip_type;
    offset += 1;

    info_ptr[offset] = @intCast(clip.name_len);
    offset += 1;

    for (0..clip.name_len) |i| {
        info_ptr[offset + i] = clip.name[i];
    }

    return @intCast(offset + clip.name_len);
}

export fn clear_clips() void {
    clip_count = 0;
    next_clip_id = 1;
}

export fn get_clip_at_time(time: f32) u32 {
    for (0..clip_count) |i| {
        const clip = &clips[i];
        if (time >= clip.start_time and time < (clip.start_time + clip.duration)) {
            return clip.id;
        }
    }
    return 0; // No clip found
}

// Enhanced timeline functions
export fn get_total_timeline_duration() f32 {
    var max_end: f32 = timeline_end;
    for (0..clip_count) |i| {
        const clip = &clips[i];
        const clip_end = clip.start_time + clip.duration;
        if (clip_end > max_end) {
            max_end = clip_end;
        }
    }
    return max_end;
}

export fn snap_time_to_clips(time: f32, snap_distance: f32) f32 {
    var closest_time = time;
    var closest_distance = snap_distance + 1.0;

    for (0..clip_count) |i| {
        const clip = &clips[i];

        // Check snap to clip start
        const start_distance = @abs(time - clip.start_time);
        if (start_distance < snap_distance and start_distance < closest_distance) {
            closest_distance = start_distance;
            closest_time = clip.start_time;
        }

        // Check snap to clip end
        const clip_end = clip.start_time + clip.duration;
        const end_distance = @abs(time - clip_end);
        if (end_distance < snap_distance and end_distance < closest_distance) {
            closest_distance = end_distance;
            closest_time = clip_end;
        }
    }

    return closest_time;
}
