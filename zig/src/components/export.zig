const std = @import("std");
const types = @import("types.zig");

pub const Export = struct {
    pub fn saveToFile(chunks: []const []const u8, filename: []const u8, allocator: std.mem.Allocator) !void {
        const blob = try createBlob(chunks, allocator);
        defer blob.deinit();
        try triggerDownload(blob, filename);
    }

    fn createBlob(chunks: []const []const u8, allocator: std.mem.Allocator) !*types.Blob {
        var total_size: usize = 0;
        for (chunks) |chunk| {
            total_size += chunk.len;
        }

        var data = try allocator.alloc(u8, total_size);
        var offset: usize = 0;
        for (chunks) |chunk| {
            std.mem.copy(u8, data[offset..], chunk);
            offset += chunk.len;
        }

        return types.Blob.init(allocator, data, "video/webm");
    }

    fn triggerDownload(blob: *types.Blob, filename: []const u8) !void {
        // Implementation would be provided by JavaScript bindings
        _ = blob;
        _ = filename;
    }
};
