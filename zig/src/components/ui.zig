const std = @import("std");
const types = @import("types.zig");
const mobile = @import("ui/mobile.zig");
const web = @import("web");
const editor = @import("editor.zig");

pub const View = enum {
    Record,
    Edit,
    Preview,
};

pub const UI = struct {
    responsive_ui: *mobile.ResponsiveUI,
    allocator: std.mem.Allocator,
    event_queue: std.ArrayList(UIEvent),
    current_view: View,

    pub fn init(allocator: std.mem.Allocator) !*UI {
        const self = try allocator.create(UI);
        self.* = .{
            .responsive_ui = try mobile.ResponsiveUI.init(allocator),
            .allocator = allocator,
            .event_queue = std.ArrayList(UIEvent).init(allocator),
            .current_view = .Record,
        };
        return self;
    }

    pub fn deinit(self: *UI) void {
        self.responsive_ui.deinit();
        self.event_queue.deinit();
        self.allocator.destroy(self);
    }

    pub fn render(self: *UI) !void {
        try self.responsive_ui.render();
        // Process any pending events
        while (self.event_queue.items.len > 0) {
            _ = self.pollEvent();
        }
    }

    pub fn pollEvent(self: *UI) ?UIEvent {
        return if (self.event_queue.items.len > 0)
            self.event_queue.orderedRemove(0)
        else
            null;
    }

    pub fn setView(self: *UI, view: View) !void {
        if (view == self.current_view) return;
        self.current_view = view;
        try self.responsive_ui.setView(view);
        try self.event_queue.append(.{ .view_changed = view });
    }

    pub fn setRecordCallback(self: *UI, callback: fn () void) void {
        self.responsive_ui.toolbar.record_button.setOnClick(callback);
    }

    pub fn setStopCallback(self: *UI, callback: fn () void) void {
        _ = self;
        _ = callback; // TODO: Implement stop callback in mobile UI
    }
};

pub const UIEvent = union(enum) {
    record,
    stop,
    save,
    edit,
    view_changed: View,
    addFilter: editor.Filter,
    addText: editor.TextOverlay,
    trim: editor.TimeRange,
    undo,
    redo,
};
