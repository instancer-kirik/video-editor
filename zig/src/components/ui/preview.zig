const std = @import("std");
const web = @import("web");
const types = @import("../types.zig");

pub const Preview = struct {
    canvas: *types.Element,
    context: *web.CanvasContext,
    video_element: *types.Element,
    width: u32,
    height: u32,
    allocator: std.mem.Allocator,
    is_visible: bool,

    pub fn init(allocator: std.mem.Allocator) !*Preview {
        const self = try allocator.create(Preview);
        self.* = .{
            .canvas = try types.Element.init(allocator, "canvas", "preview-canvas"),
            .video_element = try types.Element.init(allocator, "video", "preview-video"),
            .context = try web.getCanvasContext(self.canvas.handle),
            .width = 1280,
            .height = 720,
            .allocator = allocator,
            .is_visible = true,
        };

        try self.setupVideoElement();
        try self.setupCanvas();
        return self;
    }

    pub fn deinit(self: *Preview) void {
        self.canvas.deinit();
        self.video_element.deinit();
        self.context.deinit();
        self.allocator.destroy(self);
    }

    pub fn renderVideoFrame(self: *Preview, stream_handle: *web.MediaStreamHandle) !void {
        try self.video_element.setSrcObject(stream_handle);
        try self.video_element.play();
    }

    pub fn show(self: *Preview) !void {
        if (self.is_visible) return;
        try self.video_element.setStyle("display", "block");
        try self.canvas.setStyle("display", "block");
        self.is_visible = true;
    }

    pub fn hide(self: *Preview) !void {
        if (!self.is_visible) return;
        try self.video_element.setStyle("display", "none");
        try self.canvas.setStyle("display", "none");
        self.is_visible = false;
    }

    fn setupVideoElement(self: *Preview) !void {
        try self.video_element.setAttribute("autoplay", "true");
        try self.video_element.setAttribute("playsinline", "true");
        try self.video_element.setAttribute("muted", "true");
        try self.video_element.setStyle("width", "100%");
        try self.video_element.setStyle("height", "100%");
        try self.video_element.setStyle("object-fit", "contain");
        try self.video_element.setStyle("background", "#000");
        try self.video_element.setStyle("border-radius", "8px");
    }

    fn setupCanvas(self: *Preview) !void {
        try self.canvas.setAttribute("width", self.width);
        try self.canvas.setAttribute("height", self.height);
        try self.canvas.setStyle("display", "none"); // Hide canvas initially
        try self.canvas.setStyle("width", "100%");
        try self.canvas.setStyle("height", "100%");
        try self.canvas.setStyle("object-fit", "contain");
    }
};
