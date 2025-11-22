const std = @import("std");
const net = std.net;
const fs = std.fs;
const mem = std.mem;
const os = std.os;
const posix = std.posix;
const crypto = std.crypto;

const PORT = 8000;
const WEBSOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

// WebSocket connection list
var ws_connections = std.ArrayList(*WebSocketConnection).init(std.heap.page_allocator);

const WebSocketConnection = struct {
    stream: net.Stream,
    allocator: std.mem.Allocator,

    pub fn init(stream: net.Stream, allocator: std.mem.Allocator) !*WebSocketConnection {
        const self = try allocator.create(WebSocketConnection);
        self.* = .{
            .stream = stream,
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *WebSocketConnection) void {
        self.stream.close();
        self.allocator.destroy(self);
    }

    pub fn sendMessage(self: *WebSocketConnection, msg: []const u8) !void {
        // WebSocket frame format:
        // FIN + RSV1-3 + Opcode (1 byte)
        // Mask + Payload length (1 byte)
        // Extended payload length (0, 2, or 8 bytes)
        // Payload data
        var frame: [14]u8 = undefined;
        frame[0] = 0x81; // FIN=1, Opcode=1 (text)

        var frame_len: usize = 2;
        if (msg.len < 126) {
            frame[1] = @intCast(msg.len);
        } else if (msg.len <= 65535) {
            frame[1] = 126;
            std.mem.writeInt(u16, frame[2..4], @intCast(msg.len), .big);
            frame_len += 2;
        } else {
            frame[1] = 127;
            std.mem.writeInt(u64, frame[2..10], msg.len, .big);
            frame_len += 8;
        }

        try self.stream.writeAll(frame[0..frame_len]);
        try self.stream.writeAll(msg);
    }
};

pub fn main() !void {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create server
    const address = try net.Address.parseIp("127.0.0.1", PORT);
    const sock_flags = posix.SOCK.STREAM | posix.SOCK.CLOEXEC;
    const sockfd = try posix.socket(address.any.family, sock_flags, posix.IPPROTO.TCP);
    errdefer posix.close(sockfd);

    // Enable address reuse to avoid "Address already in use" errors
    try posix.setsockopt(
        sockfd,
        posix.SOL.SOCKET,
        posix.SO.REUSEADDR,
        &mem.toBytes(@as(c_int, 1)),
    );
    try posix.setsockopt(
        sockfd,
        posix.SOL.SOCKET,
        posix.SO.REUSEPORT,
        &mem.toBytes(@as(c_int, 1)),
    );

    try posix.bind(sockfd, &address.any, address.getOsSockLen());
    try posix.listen(sockfd, 128);

    const server = net.Stream{ .handle = sockfd };
    defer server.close();

    std.debug.print("Server listening on http://localhost:{d}\n", .{PORT});

    // Start file watcher thread
    const watcher_thread = try std.Thread.spawn(.{}, watchFiles, .{allocator});
    _ = watcher_thread;

    while (true) {
        var accepted_addr: net.Address = undefined;
        var addr_len: posix.socklen_t = @sizeOf(net.Address);
        const client_fd = try posix.accept(
            server.handle,
            @ptrCast(&accepted_addr.any),
            &addr_len,
            posix.SOCK.CLOEXEC,
        );
        const client = net.Stream{ .handle = client_fd };
        try handleConnection(allocator, client);
    }
}

fn handleConnection(allocator: std.mem.Allocator, client: net.Stream) !void {
    defer client.close();

    var buf: [4096]u8 = undefined;
    const bytes_read = try client.read(&buf);
    const request = buf[0..bytes_read];

    // Parse request to get path and headers
    var lines = std.mem.split(u8, request, "\r\n");
    const first_line = lines.first();
    var parts = std.mem.split(u8, first_line, " ");
    _ = parts.first(); // Skip method
    const path = parts.next() orelse "/";

    // Check for WebSocket upgrade request
    if (isWebSocketUpgrade(request)) {
        try handleWebSocketUpgrade(allocator, client, request);
        return;
    }

    // Clean path and map to web directory
    const clean_path = try std.fs.path.resolve(allocator, &.{path});
    defer allocator.free(clean_path);

    const web_path = try std.fs.path.join(allocator, &.{ "zig-out/web", if (mem.eql(u8, clean_path, "/")) "index.html" else clean_path[1..] });
    defer allocator.free(web_path);

    // Try to read the file
    const file = fs.cwd().openFile(web_path, .{}) catch {
        try sendResponse(client, "404 Not Found", "text/plain", "404 - File not found");
        return;
    };
    defer file.close();

    const stat = try file.stat();
    const content = try allocator.alloc(u8, @intCast(stat.size));
    defer allocator.free(content);
    _ = try file.readAll(content);

    // If it's an HTML file, inject the hot reload script
    if (mem.endsWith(u8, web_path, ".html")) {
        const modified_content = try injectHotReloadScript(allocator, content);
        defer allocator.free(modified_content);
        try sendResponse(client, "200 OK", "text/html", modified_content);
        return;
    }

    // Determine content type
    const content_type = if (mem.endsWith(u8, web_path, ".js"))
        "application/javascript"
    else if (mem.endsWith(u8, web_path, ".wasm"))
        "application/wasm"
    else
        "application/octet-stream";

    try sendResponse(client, "200 OK", content_type, content);
}

fn isWebSocketUpgrade(request: []const u8) bool {
    return mem.indexOf(u8, request, "Upgrade: websocket") != null;
}

fn handleWebSocketUpgrade(allocator: std.mem.Allocator, client: net.Stream, request: []const u8) !void {
    // Extract the Sec-WebSocket-Key header
    var lines = std.mem.split(u8, request, "\r\n");
    var key: ?[]const u8 = null;
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "Sec-WebSocket-Key:")) {
            key = std.mem.trim(u8, line["Sec-WebSocket-Key:".len..], " ");
            break;
        }
    }

    if (key == null) return error.InvalidWebSocketRequest;

    // Generate accept key
    const accept_key_input = try std.fmt.allocPrint(allocator, "{s}{s}", .{ key.?, WEBSOCKET_GUID });
    defer allocator.free(accept_key_input);

    var sha1_buf: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(accept_key_input, &sha1_buf, .{});
    var accept_key: [28]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&accept_key, &sha1_buf);

    // Send WebSocket upgrade response
    const response = try std.fmt.allocPrint(allocator,
        \\HTTP/1.1 101 Switching Protocols
        \\Upgrade: websocket
        \\Connection: Upgrade
        \\Sec-WebSocket-Accept: {s}
        \\
        \\
    , .{accept_key});
    defer allocator.free(response);

    try client.writeAll(response);

    // Create WebSocket connection and add to list
    const ws = try WebSocketConnection.init(client, allocator);
    try ws_connections.append(ws);
}

fn injectHotReloadScript(allocator: std.mem.Allocator, content: []const u8) ![]const u8 {
    const script =
        \\<script>
        \\    (function() {
        \\        const ws = new WebSocket('ws://' + location.host + '/ws');
        \\        ws.onmessage = function(event) {
        \\            if (event.data === 'reload') {
        \\                location.reload();
        \\            }
        \\        };
        \\    })();
        \\</script>
        \\</body>
    ;

    // Replace closing body tag with our script
    if (mem.indexOf(u8, content, "</body>")) |index| {
        const result = try allocator.alloc(u8, content.len + script.len - "</body>".len);
        @memcpy(result[0..index], content[0..index]);
        @memcpy(result[index..][0..script.len], script);
        @memcpy(result[index + script.len ..], content[index + "</body>".len ..]);
        return result;
    }

    return content;
}

fn watchFiles(allocator: std.mem.Allocator) !void {
    const paths_to_watch = [_][]const u8{
        "src",
        "zig-out/web",
    };

    var last_modified = std.StringHashMap(i128).init(allocator);
    defer last_modified.deinit();

    while (true) {
        var changed = false;

        for (paths_to_watch) |path| {
            var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
            defer dir.close();

            var walker = try dir.walk(allocator);
            defer walker.deinit();

            while (try walker.next()) |entry| {
                if (entry.kind != .file) continue;

                const full_path = try std.fs.path.join(allocator, &.{ path, entry.path });
                defer allocator.free(full_path);

                const stat = try entry.dir.statFile(entry.basename);
                const mtime = stat.mtime;

                const stored_mtime = last_modified.get(full_path);
                if (stored_mtime == null or stored_mtime.? != mtime) {
                    try last_modified.put(try allocator.dupe(u8, full_path), mtime);
                    changed = true;
                }
            }
        }

        if (changed) {
            // Notify all WebSocket clients to reload
            for (ws_connections.items) |ws| {
                ws.sendMessage("reload") catch continue;
            }
        }

        std.time.sleep(1 * std.time.ns_per_s); // Check every second
    }
}

fn sendResponse(client: net.Stream, status: []const u8, content_type: []const u8, content: []const u8) !void {
    const response = try std.fmt.allocPrint(
        std.heap.page_allocator,
        "HTTP/1.1 {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\n\r\n",
        .{ status, content_type, content.len },
    );
    defer std.heap.page_allocator.free(response);

    try client.writeAll(response);
    try client.writeAll(content);
}
