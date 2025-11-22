const std = @import("std");
const templates = @import("templates");
const web = @import("web");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize template manager
    var template_manager = templates.TemplateManager.init(allocator, "templates");
    defer template_manager.deinit();

    // Load templates
    try template_manager.loadTemplate("base.html");

    // Initialize web server
    var server = try web.Server.init(allocator, .{
        .port = 3000,
        .template_manager = &template_manager,
    });
    defer server.deinit();

    // Add routes
    try server.get("/", handleIndex);
    try server.get("/api/log", handleLog);

    // Start server
    std.log.info("Server listening on http://localhost:3000", .{});
    try server.start();
}

fn handleIndex(ctx: *web.Context) !void {
    try ctx.render("base.html", .{
        .title = "Video Editor",
        .description = "Record, edit, and process videos",
    });
}

fn handleLog(ctx: *web.Context) !void {
    const message = try ctx.params.get("message");
    std.log.info("Client log: {s}", .{message});
    try ctx.json(.{ .success = true });
}
