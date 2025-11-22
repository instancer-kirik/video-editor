#!/usr/bin/env python3
"""
Simple HTTP server for testing Zig WASM video editor
Serves files with proper MIME types and CORS headers for WASM
"""

import http.server
import socketserver
import os
import sys
from urllib.parse import unquote


class WASMHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=os.getcwd(), **kwargs)

    def end_headers(self):
        # Add CORS headers for cross-origin requests
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

        # Security headers for local development
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")

        super().end_headers()

    def guess_type(self, path):
        # Custom MIME types for WASM and other files
        mime_types = {
            ".wasm": "application/wasm",
            ".js": "application/javascript",
            ".mjs": "application/javascript",
            ".css": "text/css",
            ".html": "text/html",
            ".json": "application/json",
            ".png": "image/png",
            ".jpg": "image/jpeg",
            ".jpeg": "image/jpeg",
            ".gif": "image/gif",
            ".svg": "image/svg+xml",
            ".ico": "image/x-icon",
            ".mp4": "video/mp4",
            ".webm": "video/webm",
            ".mp3": "audio/mpeg",
            ".wav": "audio/wav",
        }

        # Get file extension
        _, ext = os.path.splitext(path.lower())

        # Return custom MIME type if we have one, otherwise use default
        if ext in mime_types:
            return mime_types[ext]

        return super().guess_type(path)

    def do_GET(self):
        # Handle root path redirect
        if self.path == "/":
            self.path = "/index.html"

        # Decode URL path
        path = unquote(self.path)

        # Security: prevent directory traversal
        if ".." in path or path.startswith("/.."):
            self.send_error(403, "Forbidden")
            return

        super().do_GET()

    def do_OPTIONS(self):
        # Handle preflight requests
        self.send_response(200)
        self.end_headers()


def main():
    port = 8080

    # Parse command line arguments
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print(f"Invalid port number: {sys.argv[1]}")
            sys.exit(1)

    # Print startup information
    print("=" * 60)
    print("🎬 Zig WASM Video Editor Test Server")
    print("=" * 60)
    print(f"📂 Serving directory: {os.getcwd()}")
    print(f"🌐 Server running at: http://localhost:{port}")
    print(f"🔗 Direct test link: http://localhost:{port}/test/")
    print("=" * 60)
    print("📋 Available endpoints:")
    print(f"   • Main test page: http://localhost:{port}/test/")
    print(
        f"   • WASM binary:    http://localhost:{port}/zig/zig-out/bin/video-editor.wasm"
    )
    print(f"   • Source files:   http://localhost:{port}/zig/src/")
    print("=" * 60)
    print("🔧 Features:")
    print("   • WASM MIME type support")
    print("   • CORS headers enabled")
    print("   • Security headers for SharedArrayBuffer")
    print("   • Directory traversal protection")
    print("=" * 60)
    print("Press Ctrl+C to stop the server")
    print()

    try:
        with socketserver.TCPServer(("", port), WASMHandler) as httpd:
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user")
    except OSError as e:
        print(f"❌ Error starting server: {e}")
        if "Address already in use" in str(e):
            print(f"💡 Port {port} is already in use. Try a different port:")
            print(f"   python3 serve.py {port + 1}")
        sys.exit(1)


if __name__ == "__main__":
    main()
