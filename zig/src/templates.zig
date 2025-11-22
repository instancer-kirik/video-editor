const std = @import("std");

pub const TemplateManager = struct {
    allocator: std.mem.Allocator,
    templates: std.HashMap([]const u8, Template, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),

    pub fn init(allocator: std.mem.Allocator) TemplateManager {
        return .{
            .allocator = allocator,
            .templates = std.HashMap([]const u8, Template, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
        };
    }

    pub fn deinit(self: *TemplateManager) void {
        var iterator = self.templates.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.templates.deinit();
    }

    pub fn loadTemplate(self: *TemplateManager, name: []const u8, path: []const u8) !void {
        const template = try Template.init(self.allocator, path);
        try self.templates.put(name, template);
    }

    pub fn render(self: *TemplateManager, name: []const u8, context: anytype) ![]u8 {
        const template = self.templates.get(name) orelse return error.TemplateNotFound;
        return try template.render(context);
    }
};

pub const Template = struct {
    content: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !Template {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
            error.FileNotFound => return error.TemplateNotFound,
            else => return err,
        };
        defer file.close();

        const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));

        return Template{
            .content = content,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Template) void {
        self.allocator.free(self.content);
    }

    pub fn render(self: Template, context: anytype) ![]u8 {
        // Simple template rendering - just return content for now
        // In a full implementation, you'd parse {{ variable }} syntax
        _ = context;
        return try self.allocator.dupe(u8, self.content);
    }
};

// Basic template context for HTML rendering
pub const Context = struct {
    title: []const u8 = "Video Editor",
    content: []const u8 = "",
    scripts: []const []const u8 = &.{},
    styles: []const []const u8 = &.{},

    pub fn toHtml(self: Context, allocator: std.mem.Allocator) ![]u8 {
        var html = std.ArrayList(u8).init(allocator);
        defer html.deinit();

        try html.appendSlice("<!DOCTYPE html>\n<html>\n<head>\n");
        try html.appendSlice("<meta charset=\"UTF-8\">\n");
        try html.appendSlice("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n");

        // Title
        try html.appendSlice("<title>");
        try html.appendSlice(self.title);
        try html.appendSlice("</title>\n");

        // Styles
        for (self.styles) |style| {
            try html.appendSlice("<link rel=\"stylesheet\" href=\"");
            try html.appendSlice(style);
            try html.appendSlice("\">\n");
        }

        try html.appendSlice("</head>\n<body>\n");

        // Content
        try html.appendSlice(self.content);

        // Scripts
        for (self.scripts) |script| {
            try html.appendSlice("<script src=\"");
            try html.appendSlice(script);
            try html.appendSlice("\"></script>\n");
        }

        try html.appendSlice("</body>\n</html>");

        return html.toOwnedSlice();
    }
};
