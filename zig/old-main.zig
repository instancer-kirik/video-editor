const std = @import("std");
const components = struct {
    pub const media = @import("components/media.zig");
    pub const recorder = @import("components/recorder.zig");
    pub const ui = @import("components/ui.zig");
    pub const export_ = @import("components/export.zig");
    pub const editor = @import("components/editor.zig");
};

pub fn main() !void {
    var app = try VideoApp.init();
    defer app.deinit();
    try app.run();
}

pub const VideoApp = struct {
    recorder: *components.recorder.Recorder,
    editor: *components.editor.Editor,
    ui: *components.ui.UI,
    allocator: std.mem.Allocator,
    state: AppState,

    pub fn init() !*VideoApp {
        const allocator = std.heap.page_allocator;
        const self = try allocator.create(VideoApp);
        self.* = .{
            .recorder = try components.recorder.Recorder.init(allocator),
            .editor = try components.editor.Editor.init(allocator),
            .ui = try components.ui.UI.init(allocator),
            .allocator = allocator,
            .state = .idle,
        };

        try self.setupCallbacks();
        return self;
    }

    pub fn deinit(self: *VideoApp) void {
        self.recorder.deinit();
        self.editor.deinit();
        self.ui.deinit();
        self.allocator.destroy(self);
    }

    pub fn run(self: *VideoApp) !void {
        while (true) {
            try self.ui.render();
            try self.handleEvents();
            try self.recorder.update();
            try self.editor.update();
            try self.updatePreview();
        }
    }

    fn setupCallbacks(self: *VideoApp) !void {
        self.ui.controls.setRecordCallback(self.onRecordPressed);
        self.ui.controls.setStopCallback(self.onStopPressed);
        self.ui.controls.setEditCallback(self.onEditPressed);
        self.ui.controls.setSaveCallback(self.onSavePressed);
    }

    fn handleEvents(self: *VideoApp) !void {
        while (self.ui.pollEvent()) |event| {
            switch (event) {
                .record => try self.startRecording(),
                .stop => try self.stopRecording(),
                .edit => try self.startEditing(),
                .save => try self.saveVideo(),
                .addFilter => |filter| try self.editor.addFilter(filter),
                .addText => |text| try self.editor.addText(text),
                .trim => |range| try self.editor.trim(range),
                .undo => try self.editor.undo(),
                .redo => try self.editor.redo(),
                else => {},
            }
        }
    }

    fn updatePreview(self: *VideoApp) !void {
        switch (self.state) {
            .recording => try self.recorder.renderPreview(self.ui.preview),
            .editing => try self.editor.renderPreview(self.ui.preview),
            else => {},
        }
    }
};

const AppState = enum {
    idle,
    recording,
    editing,
};
