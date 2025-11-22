const std = @import("std");
const web = @import("web");
const editor = @import("../editor.zig");
const types = @import("../types.zig");
const ui = @import("../ui.zig");

pub const ResponsiveUI = struct {
    // Main UI sections
    camera_view: *CameraView,
    timeline_view: *TimelineView,
    toolbar: *Toolbar,
    gesture_handler: *GestureHandler,
    allocator: std.mem.Allocator,
    is_mobile: bool,

    pub fn init(allocator: std.mem.Allocator) !*ResponsiveUI {
        const self = try allocator.create(ResponsiveUI);
        self.* = .{
            .camera_view = try CameraView.init(allocator),
            .timeline_view = try TimelineView.init(allocator),
            .toolbar = try Toolbar.init(allocator),
            .gesture_handler = try GestureHandler.init(allocator),
            .allocator = allocator,
            .is_mobile = detectMobile(),
        };
        try self.setupResponsiveLayout();
        return self;
    }

    fn setupResponsiveLayout(self: *ResponsiveUI) !void {
        if (self.is_mobile) {
            try self.camera_view.setFullscreenMode();
            try self.toolbar.setPosition(.bottom);
            try self.timeline_view.setCollapsible(true);
        } else {
            try self.camera_view.setDesktopMode();
            try self.toolbar.setPosition(.side);
            try self.timeline_view.setCollapsible(false);
        }
    }

    fn detectMobile() bool {
        // Use window.innerWidth to detect mobile
        // This will be implemented in JS
        return false;
    }

    pub fn render(self: *ResponsiveUI) !void {
        try self.camera_view.render();
        try self.toolbar.render();
        try self.timeline_view.render();
    }

    pub fn startTimer(self: *ResponsiveUI) !void {
        try self.toolbar.record_button.startRecording();
    }

    pub fn stopTimer(self: *ResponsiveUI) !void {
        try self.toolbar.record_button.stopRecording();
    }

    pub fn setView(self: *ResponsiveUI, view: ui.View) !void {
        switch (view) {
            .Record => {
                try self.camera_view.show();
                try self.toolbar.show();
                try self.timeline_view.hide();
            },
            .Edit => {
                try self.camera_view.hide();
                try self.toolbar.hide();
                try self.timeline_view.show();
            },
            .Preview => {
                try self.camera_view.show();
                try self.toolbar.hide();
                try self.timeline_view.show();
            },
        }
    }
};

pub const CameraView = struct {
    preview: *types.Element,
    focus_point: ?editor.Position,
    exposure_slider: *Slider,
    zoom_level: f32,
    loading_spinner: *LoadingSpinner,
    camera_select: *types.Element,
    resolution_select: *types.Element,
    framerate_select: *types.Element,
    status_display: *types.Element,

    pub fn init(allocator: std.mem.Allocator) !*CameraView {
        const self = try allocator.create(CameraView);
        self.* = .{
            .preview = try types.Element.init(allocator, "div", "preview"),
            .focus_point = null,
            .exposure_slider = try Slider.init(allocator),
            .zoom_level = 1.0,
            .loading_spinner = try LoadingSpinner.init(allocator),
            .camera_select = try types.Element.init(allocator, "select", "camera-select"),
            .resolution_select = try types.Element.init(allocator, "select", "resolution-select"),
            .framerate_select = try types.Element.init(allocator, "select", "framerate-select"),
            .status_display = try types.Element.init(allocator, "div", "status"),
        };
        try self.setupCameraView();
        return self;
    }

    fn setupCameraView(self: *CameraView) !void {
        try self.preview.setStyle("position", "relative");
        try self.preview.setStyle("width", "100%");
        try self.preview.setStyle("height", "100%");
        try self.preview.setStyle("object-fit", "cover");
        try self.preview.setStyle("background", "#000");
        try self.preview.setStyle("border-radius", "12px");
        try self.preview.setStyle("overflow", "hidden");
    }

    pub fn setFullscreenMode(self: *CameraView) !void {
        try self.preview.setStyle("position", "fixed");
        try self.preview.setStyle("width", "100vw");
        try self.preview.setStyle("height", "100vh");
        try self.preview.setStyle("border-radius", "0");
    }

    pub fn setDesktopMode(self: *CameraView) !void {
        try self.preview.setStyle("position", "relative");
        try self.preview.setStyle("width", "calc(100% - 40px)");
        try self.preview.setStyle("height", "calc(100vh - 200px)");
        try self.preview.setStyle("margin", "20px");
        try self.preview.setStyle("border-radius", "12px");
    }

    pub fn showLoading(self: *CameraView) void {
        self.loading_spinner.show();
    }

    pub fn hideLoading(self: *CameraView) void {
        self.loading_spinner.hide();
    }

    pub fn show(self: *CameraView) !void {
        try self.preview.setStyle("display", "block");
    }

    pub fn hide(self: *CameraView) !void {
        try self.preview.setStyle("display", "none");
    }

    pub fn render(self: *CameraView) !void {
        _ = self;
    }
};

pub const Toolbar = struct {
    record_button: *CircleButton,
    mode_switcher: *ModeSwitcher,
    quick_actions: std.ArrayList(*QuickAction),
    container: *types.Element,

    const QuickAction = struct {
        icon: []const u8,
        action: ActionType,
    };

    const ActionType = enum {
        flip_camera,
        flash_toggle,
        filters,
        timer,
        grid,
    };

    pub fn init(allocator: std.mem.Allocator) !*Toolbar {
        const self = try allocator.create(Toolbar);
        self.* = .{
            .record_button = try CircleButton.init(allocator, 72),
            .mode_switcher = try ModeSwitcher.init(allocator),
            .quick_actions = std.ArrayList(*QuickAction).init(allocator),
            .container = try types.Element.init(allocator, "div", "toolbar"),
        };
        try self.setupToolbar();
        return self;
    }

    fn setupToolbar(self: *Toolbar) !void {
        try self.container.setStyle("display", "flex");
        try self.container.setStyle("gap", "20px");
        try self.container.setStyle("padding", "20px");
        try self.container.setStyle("background", "rgba(0,0,0,0.8)");
        try self.container.setStyle("backdrop-filter", "blur(10px)");
        try self.container.setStyle("border-radius", "12px");
    }

    pub fn setPosition(self: *Toolbar, pos: enum { bottom, side }) !void {
        switch (pos) {
            .bottom => {
                try self.container.setStyle("position", "fixed");
                try self.container.setStyle("bottom", "0");
                try self.container.setStyle("left", "0");
                try self.container.setStyle("width", "100%");
                try self.container.setStyle("justify-content", "center");
            },
            .side => {
                try self.container.setStyle("position", "fixed");
                try self.container.setStyle("right", "20px");
                try self.container.setStyle("top", "50%");
                try self.container.setStyle("transform", "translateY(-50%)");
                try self.container.setStyle("flex-direction", "column");
            },
        }
    }

    pub fn show(self: *Toolbar) !void {
        try self.container.setStyle("display", "flex");
    }

    pub fn hide(self: *Toolbar) !void {
        try self.container.setStyle("display", "none");
    }

    pub fn render(self: *Toolbar) !void {
        _ = self;
    }
};

pub const TimelineView = struct {
    container: *types.Element,
    handle: *types.Element,
    preview: *types.Element,
    clips: std.ArrayList(*ClipThumbnail),
    trim_handles: [2]*DragHandle,
    is_collapsed: bool,
    allocator: std.mem.Allocator,

    const Callbacks = struct {
        pub fn onTimelineToggle(ctx: *anyopaque) callconv(.C) void {
            const self = @as(*TimelineView, @ptrCast(@alignCast(ctx)));
            if (self.is_collapsed) {
                // Expand
                self.container.setStyle("transform", "none") catch return;
            } else {
                // Collapse
                self.container.setStyle("transform", "translateY(calc(100% - 20px))") catch return;
            }
            self.is_collapsed = !self.is_collapsed;
        }
    };

    pub fn init(allocator: std.mem.Allocator) !*TimelineView {
        const self = try allocator.create(TimelineView);
        self.* = .{
            .container = try types.Element.init(allocator, "div", "timeline"),
            .handle = try types.Element.init(allocator, "div", "timeline-handle"),
            .preview = try types.Element.init(allocator, "div", "timeline-preview"),
            .clips = std.ArrayList(*ClipThumbnail).init(allocator),
            .trim_handles = undefined, // Will be initialized below
            .is_collapsed = false,
            .allocator = allocator,
        };

        // Initialize trim handles
        self.trim_handles[0] = try DragHandle.init(allocator);
        self.trim_handles[1] = try DragHandle.init(allocator);

        try self.setupTimelineView();
        return self;
    }

    fn setupTimelineView(self: *TimelineView) !void {
        try self.preview.setStyle("position", "relative");
        try self.preview.setStyle("width", "100%");
        try self.preview.setStyle("height", "100%");
        try self.preview.setStyle("background", "#000");
        try self.preview.setStyle("border-radius", "12px");
        try self.preview.setStyle("overflow", "hidden");

        try self.container.setStyle("position", "fixed");
        try self.container.setStyle("bottom", "0");
        try self.container.setStyle("left", "0");
        try self.container.setStyle("width", "100%");
        try self.container.setStyle("height", "200px");
        try self.container.setStyle("background", "rgba(0,0,0,0.8)");
        try self.container.setStyle("backdrop-filter", "blur(10px)");

        try self.handle.setStyle("position", "absolute");
        try self.handle.setStyle("top", "0");
        try self.handle.setStyle("left", "50%");
        try self.handle.setStyle("transform", "translateX(-50%)");
        try self.handle.setStyle("width", "50px");
        try self.handle.setStyle("height", "4px");
        try self.handle.setStyle("background", "#666");
        try self.handle.setStyle("border-radius", "2px");
        try self.handle.setStyle("cursor", "grab");

        try self.container.appendChild(self.handle);
        try self.container.appendChild(self.preview);
    }

    pub fn setCollapsible(self: *TimelineView, collapsible: bool) !void {
        if (collapsible) {
            // Set initial collapsed state
            self.is_collapsed = true;
            try self.container.setStyle("transform", "translateY(calc(100% - 20px))");

            // Add swipe gesture area
            try self.handle.setStyle("display", "block");

            // Setup touch event handlers for swipe gestures
            try self.handle.setOnClick(self, Callbacks.onTimelineToggle);
        } else {
            // Remove collapsible behavior
            self.is_collapsed = false;
            try self.container.setStyle("transform", "none");
            try self.handle.setStyle("display", "none");
        }
    }

    pub fn show(self: *TimelineView) !void {
        try self.container.setStyle("display", "block");
    }

    pub fn hide(self: *TimelineView) !void {
        try self.container.setStyle("display", "none");
    }

    pub fn render(self: *TimelineView) !void {
        // Render clips
        for (self.clips.items) |clip| {
            _ = clip; // TODO: Implement clip rendering
        }

        // Render trim handles
        for (self.trim_handles) |handle| {
            _ = handle; // TODO: Implement trim handle rendering
        }
    }

    pub fn deinit(self: *TimelineView) void {
        for (self.clips.items) |clip| {
            clip.element.deinit();
            self.allocator.destroy(clip);
        }
        self.clips.deinit();

        for (self.trim_handles) |handle| {
            handle.element.deinit();
            self.allocator.destroy(handle);
        }

        self.handle.deinit();
        self.container.deinit();
        self.allocator.destroy(self);
    }
};

pub const GestureHandler = struct {
    touch_start: ?editor.Position,
    current_gesture: ?GestureType,

    const GestureType = enum {
        pinch_zoom,
        swipe,
        tap,
        long_press,
        drag,
    };

    pub fn init(allocator: std.mem.Allocator) !*GestureHandler {
        const self = try allocator.create(GestureHandler);
        self.* = .{
            .touch_start = null,
            .current_gesture = null,
        };
        return self;
    }

    pub fn handleTouchEvent(self: *GestureHandler, event: web.TouchEvent) !void {
        switch (event) {
            .start => try self.onTouchStart(event),
            .move => try self.onTouchMove(event),
            .end => try self.onTouchEnd(event),
        }
    }
};

pub const CircleButton = struct {
    element: *types.Element,
    is_recording: bool,
    allocator: std.mem.Allocator,
    on_click: ?*const fn () void,

    pub fn init(allocator: std.mem.Allocator, size: f32) !*CircleButton {
        const self = try allocator.create(CircleButton);
        self.* = .{
            .element = try types.Element.init(allocator, "button", ""),
            .is_recording = false,
            .allocator = allocator,
            .on_click = null,
        };

        try self.element.addClass("circle-button");
        const width_str = try std.fmt.allocPrintZ(allocator, "{d}px", .{size});
        defer allocator.free(width_str);
        try self.element.setStyle("width", width_str);

        const height_str = try std.fmt.allocPrintZ(allocator, "{d}px", .{size});
        defer allocator.free(height_str);
        try self.element.setStyle("height", height_str);
        try self.element.setStyle("border-radius", "50%");
        self.is_recording = false;
        return self;
    }

    pub fn startRecording(self: *CircleButton) !void {
        try self.element.addClass("recording");
        try self.element.setStyle("background", "#ff4444");
        self.is_recording = true;
    }

    pub fn stopRecording(self: *CircleButton) !void {
        try self.element.addClass("not-recording");
        try self.element.setStyle("background", "#ffffff");
        self.is_recording = false;
    }

    pub fn setOnClick(self: *CircleButton, callback: fn () void) void {
        self.on_click = callback;
        const Context = struct {
            button: *CircleButton,
            pub fn clicked(ctx: *anyopaque) callconv(.C) void {
                const button = @as(*CircleButton, @ptrCast(@alignCast(ctx)));
                if (button.on_click) |cb| {
                    cb();
                }
            }
        };
        self.element.setOnClick(self, Context.clicked) catch {};
    }

    pub fn render(self: *CircleButton) !void {
        _ = self;
    }
};

pub const ModeSwitcher = struct {
    modes: []const Mode,
    current_mode: Mode,
    allocator: std.mem.Allocator,

    const Mode = enum {
        video,
        photo,
        portrait,
        story,
        pro,
    };

    pub fn init(allocator: std.mem.Allocator) !*ModeSwitcher {
        const self = try allocator.create(ModeSwitcher);
        self.* = .{
            .modes = &[_]Mode{ .video, .photo, .portrait, .story, .pro },
            .current_mode = .video,
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *ModeSwitcher) void {
        self.allocator.destroy(self);
    }
};

pub const Slider = struct {
    element: *types.Element,
    value: f32,
    min: f32,
    max: f32,

    pub fn init(allocator: std.mem.Allocator) !*Slider {
        const self = try allocator.create(Slider);
        self.* = .{
            .element = try types.Element.init(allocator, "input", ""),
            .value = 0,
            .min = 0,
            .max = 1,
        };
        try self.element.setAttribute("type", "range");
        try self.element.addClass("slider");
        return self;
    }

    pub fn render(self: *Slider) !void {
        _ = self;
    }
};

pub const ClipThumbnail = struct {
    element: *types.Element,
    preview: *types.Element,
    duration: f64,

    pub fn init(allocator: std.mem.Allocator) !*ClipThumbnail {
        const self = try allocator.create(ClipThumbnail);
        self.* = .{
            .element = try types.Element.init(allocator, "div", ""),
            .preview = try types.Element.init(allocator, "img", ""),
            .duration = 0,
        };
        try self.element.addClass("clip-thumbnail");
        return self;
    }
};

pub const DragHandle = struct {
    element: *types.Element,
    position: f32,

    pub fn init(allocator: std.mem.Allocator) !*DragHandle {
        const self = try allocator.create(DragHandle);
        self.* = .{
            .element = try types.Element.init(allocator, "div", ""),
            .position = 0,
        };
        try self.element.addClass("drag-handle");
        return self;
    }
};

pub const LoadingSpinner = struct {
    element: *types.Element,
    is_visible: bool,

    pub fn init(allocator: std.mem.Allocator) !*LoadingSpinner {
        const self = try allocator.create(LoadingSpinner);
        self.* = .{
            .element = try types.Element.init(allocator, "div", ""),
            .is_visible = false,
        };
        try self.element.addClass("loading-spinner");
        return self;
    }

    pub fn show(self: *LoadingSpinner) !void {
        self.is_visible = true;
        try self.element.setStyle("display", "block");
    }

    pub fn hide(self: *LoadingSpinner) !void {
        self.is_visible = false;
        try self.element.setStyle("display", "none");
    }
};
