const std = @import("std");
const web = @import("web");

// Constants for string length limits
const MAX_TAG_NAME_LENGTH = 32;
const MAX_ID_LENGTH = 64;
const MAX_ATTRIBUTE_NAME_LENGTH = 64;
const MAX_ATTRIBUTE_VALUE_LENGTH = 1024;
const MAX_STYLE_PROPERTY_LENGTH = 64;
const MAX_STYLE_VALUE_LENGTH = 1024;
const MAX_CLASS_NAME_LENGTH = 64;
const MAX_TEXT_LENGTH = 16384;

pub const Blob = struct {
    data: []const u8,
    mime_type: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, data: []const u8, mime_type: []const u8) !*Blob {
        const self = try allocator.create(Blob);
        self.* = .{
            .data = try allocator.dupe(u8, data),
            .mime_type = try allocator.dupe(u8, mime_type),
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *Blob) void {
        self.allocator.free(self.data);
        self.allocator.free(self.mime_type);
        self.allocator.destroy(self);
    }
};

pub const ElementError = error{
    EmptyTagName,
    TagNameTooLong,
    IdTooLong,
    EmptyAttributeName,
    AttributeNameTooLong,
    AttributeValueTooLong,
    EmptyStyleProperty,
    StylePropertyTooLong,
    StyleValueTooLong,
    EmptyClassName,
    ClassNameTooLong,
    TextTooLong,
    OutOfMemory,
} || web.WebError;

pub const Element = struct {
    handle: *web.Element,
    allocator: std.mem.Allocator,
    on_click: ?*const fn (*anyopaque) void,
    user_data: ?*anyopaque,

    pub fn init(allocator: std.mem.Allocator, tag_name: []const u8, id: []const u8) ElementError!*Element {
        // Validate tag name
        if (tag_name.len == 0) return error.EmptyTagName;
        if (tag_name.len > MAX_TAG_NAME_LENGTH) return error.TagNameTooLong;

        // Validate ID if provided
        if (id.len > MAX_ID_LENGTH) return error.IdTooLong;

        // Create element
        const self = try allocator.create(Element);
        errdefer allocator.destroy(self);

        // Create element with validated tag name
        const tag_z = try std.fmt.allocPrintZ(allocator, "{s}", .{tag_name});
        defer allocator.free(tag_z);

        self.* = .{
            .handle = try web.createElement(tag_z),
            .allocator = allocator,
            .on_click = null,
            .user_data = null,
        };

        // Set ID if provided
        if (id.len > 0) {
            try self.setAttribute("id", id);
        }

        return self;
    }

    pub fn deinit(self: *Element) void {
        self.handle.deinit();
        self.allocator.destroy(self);
    }

    pub fn setAttribute(self: *Element, name: []const u8, value: anytype) ElementError!void {
        // Validate attribute name
        if (name.len == 0) return error.EmptyAttributeName;
        if (name.len > MAX_ATTRIBUTE_NAME_LENGTH) return error.AttributeNameTooLong;

        // Create null-terminated name string
        const name_z = try std.fmt.allocPrintZ(self.allocator, "{s}", .{name});
        defer self.allocator.free(name_z);

        // Convert value to string based on type
        const value_str = switch (@TypeOf(value)) {
            []const u8 => value,
            [:0]const u8 => value,
            *const [*]u8 => value,
            bool => if (value) "true" else "false",
            comptime_int, u32, i32 => try std.fmt.allocPrint(self.allocator, "{d}", .{value}),
            else => blk: {
                const T = @TypeOf(value);
                if (@typeInfo(T) == .Optional) {
                    if (value) |v| {
                        break :blk try std.fmt.allocPrint(self.allocator, "{any}", .{v});
                    } else {
                        break :blk "null";
                    }
                }
                break :blk try std.fmt.allocPrint(self.allocator, "{any}", .{value});
            },
        };
        defer if (@TypeOf(value) != []const u8 and @TypeOf(value) != [:0]const u8 and @TypeOf(value) != *const [*]u8) {
            self.allocator.free(value_str);
        };

        // Validate value length
        if (value_str.len > MAX_ATTRIBUTE_VALUE_LENGTH) return error.AttributeValueTooLong;

        // Create null-terminated value string
        const value_z = try std.fmt.allocPrintZ(self.allocator, "{s}", .{value_str});
        defer self.allocator.free(value_z);

        // Set the attribute
        try web.checkStatus(self.handle.setAttribute(name_z, value_z));
    }

    pub fn setStyle(self: *Element, property: []const u8, value: []const u8) ElementError!void {
        // Validate property name and value
        if (property.len == 0) return error.EmptyStyleProperty;
        if (property.len > MAX_STYLE_PROPERTY_LENGTH) return error.StylePropertyTooLong;
        if (value.len > MAX_STYLE_VALUE_LENGTH) return error.StyleValueTooLong;

        // Create null-terminated strings
        const property_z = try std.fmt.allocPrintZ(self.allocator, "{s}", .{property});
        defer self.allocator.free(property_z);

        const value_z = try std.fmt.allocPrintZ(self.allocator, "{s}", .{value});
        defer self.allocator.free(value_z);

        // Set the style
        try web.checkStatus(self.handle.setStyle(property_z, value_z));
    }

    pub fn appendChild(self: *Element, child: *Element) ElementError!void {
        try web.checkStatus(self.handle.appendChild(child.handle));
    }

    pub fn addClass(self: *Element, class_name: []const u8) ElementError!void {
        // Validate class name
        if (class_name.len == 0) return error.EmptyClassName;
        if (class_name.len > MAX_CLASS_NAME_LENGTH) return error.ClassNameTooLong;

        // Create null-terminated string
        const class_name_z = try std.fmt.allocPrintZ(self.allocator, "{s}", .{class_name});
        defer self.allocator.free(class_name_z);

        // Add the class
        try web.checkStatus(self.handle.addClass(class_name_z));
    }

    pub fn setText(self: *Element, text: []const u8) ElementError!void {
        // Validate text length
        if (text.len > MAX_TEXT_LENGTH) return error.TextTooLong;

        // Create null-terminated string
        const text_z = try std.fmt.allocPrintZ(self.allocator, "{s}", .{text});
        defer self.allocator.free(text_z);

        // Set the text
        try web.checkStatus(self.handle.setText(text_z));
    }

    pub fn setOnClick(self: *Element, user_data: *anyopaque, callback: *const fn (*anyopaque) callconv(.C) void) ElementError!void {
        try web.checkStatus(self.handle.setOnClick(user_data, callback));
    }

    fn handleClick(element: *Element) void {
        if (element.on_click) |callback| {
            if (element.user_data) |data| {
                callback(data);
            }
        }
    }
};

pub const Button = struct {
    element: *Element,
    allocator: std.mem.Allocator,
    on_click: ?*const fn () void,

    pub fn init(allocator: std.mem.Allocator, text: []const u8) !*Button {
        const self = try allocator.create(Button);
        self.* = .{
            .element = try Element.init(allocator, "button", ""),
            .allocator = allocator,
            .on_click = null,
        };
        try self.element.setText(text);
        return self;
    }

    pub fn deinit(self: *Button) void {
        self.element.deinit();
        self.allocator.destroy(self);
    }

    pub fn setOnClick(self: *Button, callback: *const fn () void) void {
        self.on_click = callback;
    }
};
