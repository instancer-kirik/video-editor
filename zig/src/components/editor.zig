const std = @import("std");
const web = @import("web");
const types = @import("types.zig");
const ui = @import("ui.zig");
const media = @import("media.zig");

pub const Editor = struct {
    timeline: Timeline,
    layers: std.ArrayList(*Layer),
    masks: std.ArrayList(*Mask),
    tracking_points: std.ArrayList(*TrackingPoint),
    subtitles: std.ArrayList(*Subtitle),
    filters: std.ArrayList(Filter),
    text_overlays: std.ArrayList(TextOverlay),
    history: EditHistory,
    allocator: std.mem.Allocator,
    selected_layer: ?*Layer,
    duration: u32,
    current_time: u32,
    is_playing: bool,
    playback_rate: f32,
    undo_stack: std.ArrayList(Command),
    redo_stack: std.ArrayList(Command),

    pub const Command = union(enum) {
        add_layer: *Layer,
        remove_layer: *Layer,
        move_layer: struct {
            layer: *Layer,
            old_pos: Position,
            new_pos: Position,
        },
        trim_layer: struct {
            layer: *Layer,
            old_start: u32,
            new_start: u32,
            old_duration: u32,
            new_duration: u32,
        },
        add_text: struct {
            layer: *Layer,
            text: []const u8,
            position: Position,
        },
        translate_text: struct {
            layer: *Layer,
            old_text: []const u8,
            new_text: []const u8,
            language: []const u8,
        },
    };

    pub fn init(allocator: std.mem.Allocator) !*Editor {
        const self = try allocator.create(Editor);
        self.* = .{
            .timeline = try Timeline.init(allocator),
            .layers = std.ArrayList(*Layer).init(allocator),
            .masks = std.ArrayList(*Mask).init(allocator),
            .tracking_points = std.ArrayList(*TrackingPoint).init(allocator),
            .subtitles = std.ArrayList(*Subtitle).init(allocator),
            .filters = std.ArrayList(Filter).init(allocator),
            .text_overlays = std.ArrayList(TextOverlay).init(allocator),
            .history = try EditHistory.init(allocator),
            .allocator = allocator,
            .selected_layer = null,
            .duration = 0,
            .current_time = 0,
            .is_playing = false,
            .playback_rate = 1.0,
            .undo_stack = std.ArrayList(Command).init(allocator),
            .redo_stack = std.ArrayList(Command).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Editor) void {
        self.timeline.deinit();
        for (self.layers.items) |layer| layer.deinit();
        for (self.masks.items) |mask| mask.deinit();
        for (self.tracking_points.items) |point| point.deinit();
        for (self.subtitles.items) |subtitle| subtitle.deinit();
        self.layers.deinit();
        self.masks.deinit();
        self.tracking_points.deinit();
        self.subtitles.deinit();
        self.filters.deinit();
        self.text_overlays.deinit();
        self.history.deinit();
        self.undo_stack.deinit();
        self.redo_stack.deinit();
        self.allocator.destroy(self);
    }

    pub fn addFilter(self: *Editor, filter: Filter) !void {
        try self.filters.append(filter);
        try self.history.push(.{ .add_filter = filter });
    }

    pub fn addText(self: *Editor, text: TextOverlay) !void {
        try self.text_overlays.append(text);
        try self.history.push(.{ .add_text = text });
    }

    pub fn trim(self: *Editor, range: TimeRange) !void {
        try self.timeline.trim(range);
        try self.history.push(.{ .trim = range });
    }

    pub fn undo(self: *Editor) !void {
        if (try self.history.undo()) |action| {
            try self.applyAction(action);
        }
    }

    pub fn redo(self: *Editor) !void {
        if (try self.history.redo()) |action| {
            try self.applyAction(action);
        }
    }

    pub fn renderPreview(self: *Editor, preview: *ui.Preview) !void {
        try self.timeline.render(preview);
        try self.renderFilters(preview);
        try self.renderTextOverlays(preview);
    }

    // Layer management
    pub fn addLayer(self: *Editor) !void {
        const layer = try Layer.init(self.allocator);
        try self.layers.append(layer);
        try self.history.push(.{ .add_layer = layer });
    }

    // Masking
    pub fn addMask(self: *Editor, points: []const Position) !void {
        const mask = try Mask.init(self.allocator, points);
        try self.masks.append(mask);
        try self.history.push(.{ .add_mask = mask });
    }

    // Motion tracking
    pub fn addTrackingPoint(self: *Editor, point: Position) !void {
        const tracking = try TrackingPoint.init(self.allocator, point);
        try self.tracking_points.append(tracking);
        try self.history.push(.{ .add_tracking = tracking });
    }

    pub fn updateTracking(self: *Editor) !void {
        for (self.tracking_points.items) |point| {
            try point.update();
        }
    }

    // Subtitle management
    pub fn addSubtitle(self: *Editor, text: []const u8, language: Language, time_range: TimeRange) !void {
        const subtitle = try Subtitle.init(self.allocator, text, language, time_range);
        try self.subtitles.append(subtitle);
        try self.history.push(.{ .add_subtitle = subtitle });
    }

    pub fn translateSubtitles(self: *Editor, target_language: Language) !void {
        for (self.subtitles.items) |subtitle| {
            try subtitle.translate(target_language);
        }
    }

    pub fn addVideoLayer(self: *Editor, video_handle: *web.VideoHandle) !*web.Layer {
        const layer = web.VideoProcessor.createVideoLayer(video_handle) orelse return error.LayerCreationFailed;
        try self.layers.append(layer);

        // Update project duration if needed
        const layer_duration = layer.getDuration();
        self.duration = @max(self.duration, layer_duration);

        // Add to undo stack
        try self.undo_stack.append(.{ .add_layer = layer });
        self.redo_stack.clearRetainingCapacity();

        return layer;
    }

    pub fn addTextLayer(self: *Editor, text: []const u8, position: Position) !*web.Layer {
        const layer = web.createTextLayer(text) orelse return error.LayerCreationFailed;
        try self.layers.append(layer);

        layer.setPosition(position.x, position.y);
        layer.setScale(position.scale_x, position.scale_y);
        layer.setRotation(position.rotation);

        // Add to undo stack
        try self.undo_stack.append(.{
            .add_text = .{
                .layer = layer,
                .text = text,
                .position = position,
            },
        });
        self.redo_stack.clearRetainingCapacity();

        return layer;
    }

    pub fn removeLayer(self: *Editor, layer: *web.Layer) !void {
        // Find layer index
        for (self.layers.items, 0..) |l, i| {
            if (l == layer) {
                _ = self.layers.orderedRemove(i);
                // Add to undo stack
                try self.undo_stack.append(.{ .remove_layer = layer });
                self.redo_stack.clearRetainingCapacity();
                return;
            }
        }
        return error.LayerNotFound;
    }

    pub fn moveLayer(self: *Editor, layer: *web.Layer, new_pos: Position) !void {
        const old_pos = Position{
            .x = layer.getPosition().x,
            .y = layer.getPosition().y,
            .scale_x = layer.getScale().x,
            .scale_y = layer.getScale().y,
            .rotation = layer.getRotation(),
        };

        layer.setPosition(new_pos.x, new_pos.y);
        layer.setScale(new_pos.scale_x, new_pos.scale_y);
        layer.setRotation(new_pos.rotation);

        // Add to undo stack
        try self.undo_stack.append(.{
            .move_layer = .{
                .layer = layer,
                .old_pos = old_pos,
                .new_pos = new_pos,
            },
        });
        self.redo_stack.clearRetainingCapacity();
    }

    pub fn trimLayer(self: *Editor, layer: *web.Layer, new_start: u32, new_duration: u32) !void {
        const old_start = layer.getStartTime();
        const old_duration = layer.getDuration();

        layer.setStartTime(new_start);
        // Update project duration if needed
        self.duration = @max(self.duration, new_start + new_duration);

        // Add to undo stack
        try self.undo_stack.append(.{
            .trim_layer = .{
                .layer = layer,
                .old_start = old_start,
                .new_start = new_start,
                .old_duration = old_duration,
                .new_duration = new_duration,
            },
        });
        self.redo_stack.clearRetainingCapacity();
    }

    pub fn translateText(self: *Editor, layer: *web.Layer, target_language: []const u8) !void {
        if (layer.getType() != .Text) return error.NotATextLayer;

        const old_text = layer.getText();
        const new_text = try web.translateText(old_text, target_language);

        layer.setText(new_text);

        // Add to undo stack
        try self.undo_stack.append(.{
            .translate_text = .{
                .layer = layer,
                .old_text = old_text,
                .new_text = new_text,
                .language = target_language,
            },
        });
        self.redo_stack.clearRetainingCapacity();
    }

    pub fn play(self: *Editor) void {
        self.is_playing = true;
    }

    pub fn pause(self: *Editor) void {
        self.is_playing = false;
    }

    pub fn seek(self: *Editor, time: u32) void {
        self.current_time = @min(time, self.duration);
    }

    pub fn setPlaybackRate(self: *Editor, rate: f32) void {
        self.playback_rate = rate;
    }

    pub fn update(self: *Editor) !void {
        if (self.is_playing) {
            // Update current time based on playback rate (60fps)
            const delta_time: u32 = @intFromFloat(16.67 * self.playback_rate);
            self.current_time = @min(self.current_time + delta_time, self.duration);

            // Loop back to start if we reach the end
            if (self.current_time >= self.duration) {
                self.current_time = 0;
            }
        }
    }

    pub fn render(self: *Editor, ctx: *web.CanvasContext) !void {
        // Clear canvas
        try ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);

        // Render each layer in order
        for (self.layers.items) |layer| {
            if (layer.isVisible()) {
                try self.renderLayer(layer, ctx);
            }
        }
    }

    fn renderLayer(self: *Editor, layer: *web.Layer, ctx: *web.CanvasContext) !void {
        switch (layer.getType()) {
            .Video => try self.renderVideoLayer(layer, ctx),
            .Audio => {}, // Audio layers don't need visual rendering
            .Text => try self.renderTextLayer(layer, ctx),
            .Shape => try self.renderShapeLayer(layer, ctx),
            .Effect => try self.renderEffectLayer(layer, ctx),
        }
    }

    fn renderVideoLayer(self: *Editor, layer: *web.Layer, ctx: *web.CanvasContext) !void {
        const video = layer.getVideoHandle() orelse return;
        const start_time = layer.getStartTime();
        const current_time = @min(self.current_time - start_time, layer.getDuration());
        try ctx.drawVideoFrame(video, current_time);
    }

    fn renderTextLayer(self: *Editor, layer: *web.Layer, ctx: *web.CanvasContext) !void {
        const text = layer.getText();
        const pos = layer.getPosition();
        const scale = layer.getScale();
        const rotation = layer.getRotation();
        const opacity = if (layer == self.selected_layer) 1.0 else 0.8;

        try ctx.save();
        try ctx.setGlobalAlpha(opacity);
        try ctx.translate(pos.x, pos.y);
        try ctx.rotate(rotation);
        try ctx.scale(scale.x, scale.y);
        try ctx.fillText(text, 0, 0);
        try ctx.restore();
    }

    fn renderShapeLayer(self: *Editor, layer: *web.Layer, ctx: *web.CanvasContext) !void {
        const shape = layer.getShape() orelse return;
        const pos = layer.getPosition();
        const scale = layer.getScale();
        const rotation = layer.getRotation();
        const opacity = if (layer == self.selected_layer) 1.0 else 0.8;

        try ctx.save();
        try ctx.setGlobalAlpha(opacity);
        try ctx.translate(pos.x, pos.y);
        try ctx.rotate(rotation);
        try ctx.scale(scale.x, scale.y);
        try shape.render(ctx);
        try ctx.restore();
    }

    fn renderEffectLayer(self: *Editor, layer: *web.Layer, ctx: *web.CanvasContext) !void {
        const effect = layer.getEffect() orelse return;
        const opacity = if (layer == self.selected_layer) 1.0 else 0.8;
        try ctx.setGlobalAlpha(opacity);
        try effect.apply(ctx);
    }
};

pub const VideoClip = struct {
    start_time: f64,
    end_time: f64,
    source: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, source: []const u8, start: f64, end: f64) !*VideoClip {
        const self = try allocator.create(VideoClip);
        self.* = .{
            .start_time = start,
            .end_time = end,
            .source = try allocator.dupe(u8, source),
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *VideoClip) void {
        self.allocator.free(self.source);
        self.allocator.destroy(self);
    }
};

pub const Position = struct {
    x: f32,
    y: f32,
    scale_x: f32 = 1.0,
    scale_y: f32 = 1.0,
    rotation: f32 = 0.0,
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }
};

const Timeline = struct {
    clips: std.ArrayList(*VideoClip),
    current_time: f64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Timeline {
        return Timeline{
            .clips = std.ArrayList(*VideoClip).init(allocator),
            .current_time = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Timeline) void {
        for (self.clips.items) |clip| {
            clip.deinit();
        }
        self.clips.deinit();
    }
};

pub const Filter = struct {
    type: FilterType,
    intensity: f32,
    params: std.StringHashMap(f32),
};

const FilterType = enum {
    brightness,
    contrast,
    saturation,
    blur,
    vintage,
    custom,
};

pub const TextOverlay = struct {
    text: []const u8,
    position: Position,
    font_size: u32,
    color: Color,
    start_time: f64,
    end_time: f64,
};

pub const TimeRange = struct {
    start: f64,
    end: f64,
};

pub const EditHistory = struct {
    actions: std.ArrayList(EditAction),
    current_index: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !EditHistory {
        return EditHistory{
            .actions = std.ArrayList(EditAction).init(allocator),
            .current_index = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EditHistory) void {
        self.actions.deinit();
    }
};

const EditAction = union(enum) {
    add_filter: Filter,
    add_text: TextOverlay,
    trim: TimeRange,
    remove_filter: Filter,
    remove_text: TextOverlay,
    add_layer: *Layer,
    add_mask: *Mask,
    add_tracking: *TrackingPoint,
    add_subtitle: *Subtitle,
};

pub const Layer = struct {
    clips: std.ArrayList(*VideoClip),
    effects: std.ArrayList(*Effect),
    opacity: f32,
    blend_mode: BlendMode,
    is_visible: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*Layer {
        const self = try allocator.create(Layer);
        self.* = .{
            .clips = std.ArrayList(*VideoClip).init(allocator),
            .effects = std.ArrayList(*Effect).init(allocator),
            .opacity = 1.0,
            .blend_mode = .normal,
            .is_visible = true,
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *Layer) void {
        for (self.clips.items) |clip| clip.deinit();
        for (self.effects.items) |effect| effect.deinit();
        self.clips.deinit();
        self.effects.deinit();
        self.allocator.destroy(self);
    }
};

pub const Effect = struct {
    type: EffectType,
    params: std.StringHashMap(f32),
    keyframes: std.ArrayList(Keyframe),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, effect_type: EffectType) !*Effect {
        const self = try allocator.create(Effect);
        self.* = .{
            .type = effect_type,
            .params = std.StringHashMap(f32).init(allocator),
            .keyframes = std.ArrayList(Keyframe).init(allocator),
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *Effect) void {
        self.params.deinit();
        self.keyframes.deinit();
        self.allocator.destroy(self);
    }
};

pub const EffectType = enum {
    blur,
    color_correction,
    transform,
    mask,
    tracking,
    custom,
};

pub const BlendMode = enum {
    normal,
    multiply,
    screen,
    overlay,
    darken,
    lighten,
};

pub const Mask = struct {
    points: std.ArrayList(Position),
    feather: f32,
    invert: bool,
    tracking_point: ?*TrackingPoint,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, points: []const Position) !*Mask {
        const self = try allocator.create(Mask);
        self.* = .{
            .points = std.ArrayList(Position).init(allocator),
            .feather = 0,
            .invert = false,
            .tracking_point = null,
            .allocator = allocator,
        };
        try self.points.appendSlice(points);
        return self;
    }

    pub fn deinit(self: *Mask) void {
        self.points.deinit();
        self.allocator.destroy(self);
    }
};

pub const TrackingPoint = struct {
    position: Position,
    keyframes: std.ArrayList(TrackingKeyframe),
    tracked_objects: std.ArrayList(*TrackedObject),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, pos: Position) !*TrackingPoint {
        const self = try allocator.create(TrackingPoint);
        self.* = .{
            .position = pos,
            .keyframes = std.ArrayList(TrackingKeyframe).init(allocator),
            .tracked_objects = std.ArrayList(*TrackedObject).init(allocator),
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *TrackingPoint) void {
        self.keyframes.deinit();
        for (self.tracked_objects.items) |obj| obj.deinit();
        self.tracked_objects.deinit();
        self.allocator.destroy(self);
    }

    pub fn update(self: *TrackingPoint) !void {
        _ = self; // Acknowledge unused parameter
        // TODO: Implement motion tracking update logic
    }
};

pub const TrackedObject = struct {
    bounds: Rect,
    template: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, bounds: Rect, template: []const u8) !*TrackedObject {
        const self = try allocator.create(TrackedObject);
        self.* = .{
            .bounds = bounds,
            .template = try allocator.dupe(u8, template),
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *TrackedObject) void {
        self.allocator.free(self.template);
        self.allocator.destroy(self);
    }
};

pub const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const TrackingKeyframe = struct {
    time: f64,
    position: Position,
};

pub const Keyframe = struct {
    time: f64,
    value: f32,
};

pub const Subtitle = struct {
    text: []const u8,
    language: Language,
    time_range: TimeRange,
    position: Position,
    style: SubtitleStyle,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, text: []const u8, lang: Language, range: TimeRange) !*Subtitle {
        const self = try allocator.create(Subtitle);
        self.* = .{
            .text = try allocator.dupe(u8, text),
            .language = lang,
            .time_range = range,
            .position = .{ .x = 0.5, .y = 0.9 }, // Default bottom center
            .style = .default,
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *Subtitle) void {
        self.allocator.free(self.text);
        self.allocator.destroy(self);
    }

    pub fn translate(self: *Subtitle, target_lang: Language) !void {
        _ = self; // Acknowledge unused parameter
        _ = target_lang; // Acknowledge unused parameter
        // TODO: Implement translation logic
    }
};

pub const Language = enum {
    english,
    spanish,
    french,
    german,
    japanese,
    chinese,
    korean,
};

pub const SubtitleStyle = enum {
    default,
    bold,
    italic,
    outline,
    shadow,
};
