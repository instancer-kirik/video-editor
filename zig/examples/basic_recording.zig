const std = @import("std");
const root = @import("main");
const VideoApp = root.VideoApp;

pub fn main() !void {
    // Initialize the app
    var app = try VideoApp.init();
    defer app.deinit();

    // Setup callbacks
    try app.setupCallbacks();

    // Start recording flow
    try startRecordingFlow(app);
}

fn startRecordingFlow(app: *VideoApp) !void {
    std.debug.print("Starting recording...\n", .{});

    // Start recording
    try app.startRecording();

    // Record for 5 seconds
    std.time.sleep(5 * std.time.ns_per_s);

    // Stop recording
    try app.stopRecording();

    std.debug.print("Recording stopped. Saving video...\n", .{});

    // Save the recording
    try app.saveVideo();

    std.debug.print("Video saved!\n", .{});
}

// Add missing functions to VideoApp
pub fn startRecording(self: *VideoApp) !void {
    try self.recorder.start();
    self.state = .recording;
    try self.ui.controls.startTimer();
    try self.ui.controls.record_button.element.setStyle("display", "none");
    try self.ui.controls.stop_button.element.setStyle("display", "block");
}

pub fn stopRecording(self: *VideoApp) !void {
    try self.recorder.stop();
    self.state = .idle;
    self.ui.controls.stopTimer();
    try self.ui.controls.record_button.element.setStyle("display", "block");
    try self.ui.controls.stop_button.element.setStyle("display", "none");
}

pub fn saveVideo(self: *VideoApp) !void {
    const timestamp = std.time.timestamp();
    const filename = try std.fmt.allocPrint(self.allocator, "recording_{}.webm", .{timestamp});
    defer self.allocator.free(filename);

    try self.components.export_.Export.saveToFile(self.recorder.chunks.items, filename, self.allocator);
}
