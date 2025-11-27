#!/bin/bash

# Local WiFi Deployment Script for Mobile Video Recorder
# This script builds the app and serves it on your local network
# so you can access it from any phone/tablet on the same WiFi

set -e

echo "📱 Setting up Mobile Video Recorder on local WiFi..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Get local IP address
get_local_ip() {
    # Try different methods to get local IP
    if command -v hostname &> /dev/null; then
        LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null)
    fi

    if [ -z "$LOCAL_IP" ]; then
        LOCAL_IP=$(ip route get 1 | awk '{print $7; exit}' 2>/dev/null)
    fi

    if [ -z "$LOCAL_IP" ]; then
        LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
    fi

    if [ -z "$LOCAL_IP" ]; then
        LOCAL_IP="localhost"
        echo -e "${YELLOW}Warning: Could not detect local IP, using localhost${NC}"
    fi
}

# Build the mobile app
echo -e "${BLUE}Building mobile app...${NC}"
if [ -f "./build-mobile-simple.sh" ]; then
    ./build-mobile-simple.sh
else
    echo -e "${RED}Error: build-mobile-simple.sh not found!${NC}"
    echo "Make sure you're running this from the video-editor directory"
    exit 1
fi

# Get local IP
get_local_ip

# Navigate to web directory
WEB_DIR="zig/zig-out/web"
if [ ! -d "$WEB_DIR" ]; then
    echo -e "${RED}Error: Web directory not found at $WEB_DIR${NC}"
    exit 1
fi

cd "$WEB_DIR"

# Create a simple server script that binds to all interfaces
cat > local-server.py << 'EOF'
#!/usr/bin/env python3
import http.server
import ssl
import os
import subprocess
import sys
import socket

PORT = 8443
HOST = '0.0.0.0'  # Bind to all interfaces

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory='.', **kwargs)

    extensions_map = {
        '.html': 'text/html',
        '.js': 'application/javascript',
        '.css': 'text/css',
        '.json': 'application/manifest+json',
        '.wasm': 'application/wasm',
        '.png': 'image/png',
        '.svg': 'image/svg+xml'
    }

    def end_headers(self):
        # Add CORS headers for local development
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

# Create self-signed certificate if it doesn't exist
if not os.path.exists('cert.pem') or not os.path.exists('key.pem'):
    print("Creating self-signed certificate...")
    try:
        subprocess.run([
            'openssl', 'req', '-x509', '-newkey', 'rsa:2048',
            '-keyout', 'key.pem', '-out', 'cert.pem',
            '-days', '365', '-nodes',
            '-subj', '/CN=*'
        ], check=True, capture_output=True)
    except subprocess.CalledProcessError:
        print("Error: OpenSSL not found. Falling back to HTTP (camera won't work)")
        # Fallback to HTTP server
        print(f"\n🌐 HTTP Server running at:")
        print(f"   Local: http://localhost:{PORT}/mobile.html")

        server = http.server.HTTPServer((HOST, PORT), CustomHandler)
        server.serve_forever()
        sys.exit(0)

# Start HTTPS server
print(f"🔒 HTTPS Server starting...")
try:
    server = http.server.HTTPServer((HOST, PORT), CustomHandler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain('cert.pem', 'key.pem')
    server.socket = context.wrap_socket(server.socket, server_side=True)

    # Get all local IP addresses
    hostname = socket.gethostname()
    local_ips = []

    try:
        # Get all network interfaces
        import netifaces
        for interface in netifaces.interfaces():
            addrs = netifaces.ifaddresses(interface)
            if netifaces.AF_INET in addrs:
                for addr in addrs[netifaces.AF_INET]:
                    ip = addr['addr']
                    if not ip.startswith('127.'):
                        local_ips.append(ip)
    except ImportError:
        # Fallback method
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            local_ips.append(s.getsockname()[0])

    print(f"\n🌐 Mobile Video Recorder is now running!")
    print(f"📱 Access from your phone using any of these URLs:")
    print(f"   • https://localhost:{PORT}/mobile.html (this computer)")

    for ip in local_ips:
        print(f"   • https://{ip}:{PORT}/mobile.html (from phone)")

    print(f"\n📋 Setup Instructions:")
    print(f"1. Connect your phone to the same WiFi network")
    print(f"2. Open one of the URLs above in your phone's browser")
    print(f"3. Accept the security certificate warning")
    print(f"4. Grant camera and microphone permissions")
    print(f"5. Tap 'Add to Home Screen' for app-like experience")
    print(f"6. Start recording! 🎬")
    print(f"\n⚠️  Note: You'll see a security warning - this is normal for self-signed certificates")
    print(f"💡 Tip: Bookmark the URL or add to home screen for easy access")
    print(f"\n🛑 Press Ctrl+C to stop the server")
    print(f"" + "="*60)

    server.serve_forever()

except KeyboardInterrupt:
    print(f"\n\n🛑 Server stopped. Thanks for using Mobile Video Recorder!")
except Exception as e:
    print(f"Error starting server: {e}")
    sys.exit(1)
EOF

chmod +x local-server.py

echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo -e "${BLUE}🚀 Starting local WiFi server...${NC}"
echo ""
echo -e "${YELLOW}📱 Instructions:${NC}"
echo "1. Keep this terminal open"
echo "2. Connect your phone to the same WiFi network"
echo "3. Use the URL shown below on your phone"
echo "4. Accept the security certificate"
echo "5. Grant camera permissions"
echo "6. Start recording!"
echo ""
echo -e "${BLUE}🌐 Your Mobile Video Recorder will be available at:${NC}"
echo "   https://$LOCAL_IP:8443/mobile.html"
echo ""

# Start the server
python3 local-server.py
