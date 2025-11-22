const std = @import("std");
const templates = @import("templates");

pub fn init() !void {
    std.log.info("Initializing WASM bindings and setup browser environment", .{});

    // Initialize WASM bindings and setup browser environment
}

pub fn deinit() void {
    // Cleanup resources
}

pub const Event = union(enum) {
    StartRecording,
    StopRecording,
    SaveVideo,
    Exit,
    Unknown,
};

pub fn pollEvent() ?Event {
    // Poll for browser events
    return null;
}

pub fn requestAnimationFrame() !void {
    // Request next animation frame from browser
}

pub const WebError = error{
    InvalidArgument,
    OperationFailed,
    ElementNotFound,
    NetworkError,
};

pub const WebStatus = enum(c_int) {
    Success = 0,
    InvalidArgument = 1,
    OperationFailed = 2,
    ElementNotFound = 3,
    NetworkError = 4,
};

pub fn checkStatus(status: c_int) WebError!void {
    return switch (@as(WebStatus, @enumFromInt(status))) {
        .Success => {},
        .InvalidArgument => error.InvalidArgument,
        .OperationFailed => error.OperationFailed,
        .ElementNotFound => error.ElementNotFound,
        .NetworkError => error.NetworkError,
    };
}

pub const Element = opaque {
    pub extern fn setAttribute(self: *Element, name: [*:0]const u8, value: [*:0]const u8) c_int;
    pub extern fn setStyle(self: *Element, property: [*:0]const u8, value: [*:0]const u8) c_int;
    pub extern fn setSrcObject(self: *Element, stream: *MediaStreamHandle) c_int;
    pub extern fn play(self: *Element) c_int;
    pub extern fn appendChild(self: *Element, child: *Element) c_int;
    pub extern fn addClass(self: *Element, class_name: [*:0]const u8) c_int;
    pub extern fn setText(self: *Element, text: [*:0]const u8) c_int;
    pub extern fn setOnClick(self: *Element, user_data: *anyopaque, callback: *const fn (*anyopaque) callconv(.C) void) c_int;
    pub extern fn deinit(self: *Element) void;
};

pub const CanvasContext = opaque {
    pub extern fn drawImage(self: *CanvasContext, image: *Element, x: f32, y: f32, width: f32, height: f32) void;
    pub extern fn clearRect(self: *CanvasContext, x: f32, y: f32, width: f32, height: f32) void;
    pub extern fn deinit(self: *CanvasContext) void;
};

pub const TimerHandle = opaque {
    pub extern fn clear(self: *TimerHandle) void;
};

pub const MediaStreamHandle = opaque {
    pub extern fn deinit(self: *MediaStreamHandle) void;
    pub extern fn stop(self: *MediaStreamHandle) void;
    pub extern fn getVideoTrack(self: *MediaStreamHandle) *MediaTrackHandle;
    pub extern fn getAudioTrack(self: *MediaStreamHandle) *MediaTrackHandle;
};

pub const MediaTrackHandle = opaque {
    pub extern fn enable(self: *MediaTrackHandle) void;
    pub extern fn disable(self: *MediaTrackHandle) void;
    pub extern fn deinit(self: *MediaTrackHandle) void;
};

pub const VideoProcessor = struct {
    pub const VideoMetadata = struct {
        duration_ms: u32,
        width: u32,
        height: u32,
        frame_rate: f32,
    };

    pub const VideoHandle = opaque {
        pub extern fn getDuration(self: *VideoHandle) u32;
        pub extern fn getWidth(self: *VideoHandle) u32;
        pub extern fn getHeight(self: *VideoHandle) u32;
        pub extern fn getFrameRate(self: *VideoHandle) f32;
        pub extern fn getCurrentTime(self: *VideoHandle) f32;
        pub extern fn setCurrentTime(self: *VideoHandle, time: f32) void;
        pub extern fn play(self: *VideoHandle) void;
        pub extern fn pause(self: *VideoHandle) void;
        pub extern fn seek(self: *VideoHandle, time: f32) void;
        pub extern fn deinit(self: *VideoHandle) void;
    };

    pub extern fn createVideoFromBlob(blob_ptr: [*]const u8, blob_len: usize) ?*VideoHandle;
    pub extern fn getVideoMetadata(handle: *VideoHandle) VideoMetadata;
    pub extern fn createVideoLayer(handle: *VideoHandle) ?*Layer;
};

pub const Layer = opaque {
    pub extern fn getId(self: *Layer) u64;
    pub extern fn getType(self: *Layer) LayerType;
    pub extern fn setVisible(self: *Layer, visible: bool) void;
    pub extern fn setLocked(self: *Layer, locked: bool) void;
    pub extern fn setPosition(self: *Layer, x: f32, y: f32) void;
    pub extern fn setScale(self: *Layer, x: f32, y: f32) void;
    pub extern fn setRotation(self: *Layer, angle: f32) void;
    pub extern fn setStartTime(self: *Layer, time_ms: u32) void;
    pub extern fn getDuration(self: *Layer) u32;
    pub extern fn deinit(self: *Layer) void;
};

pub const LayerType = enum(u8) {
    Video,
    Audio,
    Text,
    Shape,
    Effect,
};

pub const MediaRecorderHandle = if (is_test) struct {
    pub fn start(self: *MediaRecorderHandle, timeslice_ms: u32) void {
        _ = self;
        _ = timeslice_ms;
    }
    pub fn stop(self: *MediaRecorderHandle) void {
        _ = self;
    }
    pub fn getState(self: *MediaRecorderHandle) MediaRecorderState {
        _ = self;
        return .Inactive;
    }
    pub fn deinit(self: *MediaRecorderHandle) void {
        _ = self;
    }
    pub fn setDataAvailableCallback(self: *MediaRecorderHandle, callback: *const fn ([*]const u8, usize) callconv(.C) void) void {
        _ = self;
        _ = callback;
    }
    pub fn setErrorCallback(self: *MediaRecorderHandle, callback: *const fn ([*:0]const u8) callconv(.C) void) void {
        _ = self;
        _ = callback;
    }
} else opaque {
    pub extern fn start(self: *MediaRecorderHandle, timeslice_ms: u32) void;
    pub extern fn stop(self: *MediaRecorderHandle) void;
    pub extern fn getState(self: *MediaRecorderHandle) MediaRecorderState;
    pub extern fn deinit(self: *MediaRecorderHandle) void;
    pub extern fn setDataAvailableCallback(self: *MediaRecorderHandle, callback: *const fn ([*]const u8, usize) callconv(.C) void) void;
    pub extern fn setErrorCallback(self: *MediaRecorderHandle, callback: *const fn ([*:0]const u8) callconv(.C) void) void;
};

pub const MediaRecorderState = enum(u8) {
    Inactive,
    Recording,
    Paused,
};

pub const PreviewHandle = opaque {
    pub extern fn setVideoSource(self: *PreviewHandle, stream: *MediaStreamHandle) void;
    pub extern fn setCanvas(self: *PreviewHandle, canvas: *Element) void;
    pub extern fn start(self: *PreviewHandle) void;
    pub extern fn stop(self: *PreviewHandle) void;
    pub extern fn deinit(self: *PreviewHandle) void;
};

pub fn deinitMediaRecorder(handle: *MediaRecorderHandle) void {
    handle.deinit();
}

pub fn createMediaRecorder(
    stream: *MediaStreamHandle,
    options: *const MediaRecorderOptions,
    data_callback: *const fn ([*]const u8, usize) callconv(.C) void,
) ?*MediaRecorderHandle {
    if (is_test) {
        const handle = @as(*MediaRecorderHandle, @ptrFromInt(0xdeadbeef));
        handle.setDataAvailableCallback(data_callback);
        handle.setErrorCallback(defaultErrorCallback);
        return handle;
    } else {
        // Call the JS function to create a media recorder
        const handle = createMediaRecorderJS(stream, options) orelse return null;
        handle.setDataAvailableCallback(data_callback);
        handle.setErrorCallback(defaultErrorCallback);
        return handle;
    }
}

extern "env" fn createMediaRecorderJS(stream: *MediaStreamHandle, options: *const MediaRecorderOptions) ?*MediaRecorderHandle;

fn defaultErrorCallback(message: [*:0]const u8) callconv(.C) void {
    std.log.err("MediaRecorder error: {s}", .{message});
}

// Conditional extern/implementation based on test mode
const is_test = @import("builtin").is_test;

pub fn createPreviewHandle(canvas: *Element) ?*PreviewHandle {
    const handle = createPreviewHandleInternal() orelse return null;
    handle.setCanvas(canvas);
    return handle;
}

pub fn createPreviewHandleInternal() ?*PreviewHandle {
    if (is_test) {
        return @ptrFromInt(0xdeadbeef);
    }
    @compileError("createPreviewHandleInternal is only available in test mode");
}

pub const StreamOptions = struct {
    video: VideoOptions,
    audio: AudioOptions,
};

pub const VideoOptions = struct {
    width: u32 = 1280,
    height: u32 = 720,
    frameRate: u32 = 30,
    facingMode: FacingMode = .user,
};

pub const AudioOptions = struct {
    echoCancellation: bool = true,
    noiseSuppression: bool = true,
    autoGainControl: bool = true,
    sampleRate: u32 = 48000,
    channelCount: u8 = 2,
};

pub const FacingMode = enum {
    user,
    environment,
};

pub const MediaConstraints = struct {
    video: VideoConstraints,
    audio: AudioConstraints,
};

pub const VideoConstraints = struct {
    width: u32,
    height: u32,
    framerate: u32,
};

pub const AudioConstraints = struct {
    echoCancellation: bool,
    noiseSuppression: bool,
};

pub const MediaRecorderOptions = struct {
    mimeType: []const u8,
    videoBitsPerSecond: u32,
    audioBitsPerSecond: u32,
};

pub const document = struct {
    pub const body = opaque {
        pub extern fn appendChild(child: *Element) void;
    };
};

pub const Blob = struct {
    data: []const u8,
    mime_type: []const u8,
    allocator: std.mem.Allocator,
};

// Browser API bindings
pub fn getUserMedia(constraints: *const MediaConstraints) !*MediaStreamHandle {
    _ = constraints;
    // Return a non-null pointer for testing
    return @ptrFromInt(0xdeadbeef);
}

pub fn createElement(tag_name: []const u8) !*Element {
    _ = tag_name;
    return undefined;
}

pub fn getCanvasContext(canvas: *Element) !*CanvasContext {
    _ = canvas;
    return undefined;
}

pub fn setInterval(callback: fn () void, ms: u32) !*TimerHandle {
    _ = callback;
    _ = ms;
    return undefined;
}

pub fn createBlob(chunks: []const []const u8) !*Blob {
    _ = chunks;
    return undefined;
}

pub fn downloadBlob(blob: *Blob, filename: []const u8) !void {
    _ = blob;
    _ = filename;
}

extern fn setIntervalJS(callback: fn () void, ms: u32) ?*TimerHandle;

// Add stub implementations for testing
pub fn deinitMediaStream(handle: *MediaStreamHandle) void {
    _ = handle;
}

pub fn stopMediaStream(handle: *MediaStreamHandle) void {
    _ = handle;
}

pub fn getVideoTrack(handle: *MediaStreamHandle) *MediaTrackHandle {
    _ = handle;
    return undefined;
}

pub fn getAudioTrack(handle: *MediaStreamHandle) *MediaTrackHandle {
    _ = handle;
    return undefined;
}

pub const TouchEvent = struct {
    touches: []const Touch,
    changed_touches: []const Touch,
    target: *Element,
    timestamp: f64,
};

pub const Touch = struct {
    identifier: i32,
    target: *Element,
    client_x: f32,
    client_y: f32,
    page_x: f32,
    page_y: f32,
    force: f32,
};

pub fn requestFullscreen(element: *Element) !void {
    if (element.requestFullscreen) {
        try element.requestFullscreen();
    }
}

pub fn lockOrientation(orientation: Orientation) !void {
    _ = orientation; // Acknowledge unused parameter
    // TODO: Implement actual screen orientation locking in JS bindings
}

pub const Orientation = enum {
    portrait,
    landscape,
};

pub const CameraInitError = error{
    PermissionDenied,
    DeviceNotFound,
    NotSupported,
    Timeout,
    Unknown,
};

pub const CameraErrorCode = c_int;
pub const CAMERA_ERROR_NONE: CameraErrorCode = 0;
pub const CAMERA_ERROR_PERMISSION_DENIED: CameraErrorCode = 1;
pub const CAMERA_ERROR_DEVICE_NOT_FOUND: CameraErrorCode = 2;
pub const CAMERA_ERROR_NOT_SUPPORTED: CameraErrorCode = 3;
pub const CAMERA_ERROR_TIMEOUT: CameraErrorCode = 4;

// Export the callback function so it can be called from JavaScript
export fn onCameraInitCallback(stream: ?*MediaStreamHandle, err_code: CameraErrorCode) callconv(.C) void {
    if (Callback.stored_callback) |cb| {
        if (err_code != CAMERA_ERROR_NONE) {
            const err: CameraInitError = switch (err_code) {
                CAMERA_ERROR_PERMISSION_DENIED => error.PermissionDenied,
                CAMERA_ERROR_DEVICE_NOT_FOUND => error.DeviceNotFound,
                CAMERA_ERROR_NOT_SUPPORTED => error.NotSupported,
                CAMERA_ERROR_TIMEOUT => error.Timeout,
                else => error.Unknown,
            };
            cb(null, err);
            return;
        }
        cb(stream, null);
    }
}

const Callback = struct {
    var stored_callback: ?*const fn (?*MediaStreamHandle, ?CameraInitError) void = null;
};

pub fn initializeCamera(constraints: *const MediaConstraints, callback: *const fn (?*MediaStreamHandle, ?CameraInitError) void) void {
    Callback.stored_callback = callback;
    initCameraJS(constraints);
}

extern "env" fn initCameraJS(constraints: *const MediaConstraints) void;

pub fn startMediaRecorder(handle: *MediaRecorderHandle, timeslice_ms: u32) void {
    handle.start(timeslice_ms);
}

pub fn stopMediaRecorder(handle: *MediaRecorderHandle) void {
    handle.stop();
}
pub fn startMediaRecording(stream: *MediaStreamHandle) !void {
    std.log.info("startMediaRecord ing", .{});
    _ = stream;
}

pub fn stopMediaRecording(stream: *MediaStreamHandle) !void {
    std.log.info("stopMediaRecording", .{});
    _ = stream;
}

pub const Context = struct {
    allocator: std.mem.Allocator,
    params: std.StringHashMap([]const u8),
    response: std.ArrayList(u8),
    template_manager: *templates.TemplateManager,

    pub fn init(allocator: std.mem.Allocator, template_manager: *templates.TemplateManager) Context {
        return .{
            .allocator = allocator,
            .params = std.StringHashMap([]const u8).init(allocator),
            .response = std.ArrayList(u8).init(allocator),
            .template_manager = template_manager,
        };
    }

    pub fn deinit(self: *Context) void {
        var it = self.params.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.params.deinit();
        self.response.deinit();
    }

    pub fn render(self: *Context, template_name: []const u8, data: anytype) !void {
        const html = try self.template_manager.render(template_name, data);
        defer self.allocator.free(html);
        try self.response.appendSlice(html);
    }

    pub fn json(self: *Context, data: anytype) !void {
        try self.response.appendSlice("application/json");
        try std.json.stringify(data, .{}, self.response.writer());
    }
};

pub const Server = struct {
    allocator: std.mem.Allocator,
    template_manager: *templates.TemplateManager,
    port: u16,
    routes: std.StringHashMap(HandlerFn),
    server: std.net.Server,

    const HandlerFn = *const fn (*Context) anyerror!void;

    pub const Options = struct {
        port: u16,
        template_manager: *templates.TemplateManager,
    };

    pub fn init(allocator: std.mem.Allocator, options: Options) !Server {
        const address = try std.net.Address.parseIp("127.0.0.1", options.port);
        const server = try std.net.Server.init(.{
            .reuse_address = true,
        });
        errdefer server.deinit();

        try server.listen(address);

        return Server{
            .allocator = allocator,
            .template_manager = options.template_manager,
            .port = options.port,
            .routes = std.StringHashMap(HandlerFn).init(allocator),
            .server = server,
        };
    }

    pub fn deinit(self: *Server) void {
        self.routes.deinit();
        self.server.deinit();
    }

    pub fn get(self: *Server, path: []const u8, handler: HandlerFn) !void {
        const key = try std.fmt.allocPrint(self.allocator, "GET {s}", .{path});
        errdefer self.allocator.free(key);
        try self.routes.put(key, handler);
    }

    pub fn start(self: *Server) !void {
        while (true) {
            const connection = try self.server.accept();
            defer connection.stream.close();

            var buf: [4096]u8 = undefined;
            const bytes_read = try connection.stream.read(&buf);
            const request = buf[0..bytes_read];

            var ctx = Context.init(self.allocator, self.template_manager);
            defer ctx.deinit();

            if (try self.handleRequest(&ctx, request)) {
                _ = try connection.stream.write(ctx.response.items);
            } else {
                _ = try connection.stream.write("HTTP/1.1 404 Not Found\r\n\r\nNot Found");
            }
        }
    }

    fn handleRequest(self: *Server, ctx: *Context, request: []const u8) !bool {
        var lines = std.mem.split(u8, request, "\r\n");
        const first_line = lines.first();
        var parts = std.mem.split(u8, first_line, " ");
        const method = parts.next() orelse return false;
        const path = parts.next() orelse return false;

        const key = try std.fmt.allocPrint(self.allocator, "{s} {s}", .{ method, path });
        defer self.allocator.free(key);

        if (self.routes.get(key)) |handler| {
            try handler(ctx);
            return true;
        }

        return false;
    }
};
