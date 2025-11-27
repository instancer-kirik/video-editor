#!/bin/bash

# Mobile Video Recorder Build Script
# This script builds the mobile PWA for deployment

set -e  # Exit on any error

echo "🎬 Building Mobile Video Recorder..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIG_DIR="$PROJECT_DIR/zig"
BUILD_DIR="$ZIG_DIR/zig-out"
WEB_DIR="$BUILD_DIR/web"

echo -e "${BLUE}Project directory: $PROJECT_DIR${NC}"

# Check if zig is installed
if ! command -v zig &> /dev/null; then
    echo -e "${RED}Error: Zig is not installed or not in PATH${NC}"
    echo "Please install Zig from https://ziglang.org/"
    exit 1
fi

# Check zig version
ZIG_VERSION=$(zig version)
echo -e "${BLUE}Using Zig version: $ZIG_VERSION${NC}"

# Navigate to zig directory
cd "$ZIG_DIR"

# Clean previous build
echo -e "${YELLOW}Cleaning previous build...${NC}"
if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
fi

# Build the project
echo -e "${YELLOW}Building WebAssembly module...${NC}"
zig build mobile --summary all

# Check if build was successful
if [ ! -f "$BUILD_DIR/bin/video-editor.wasm" ]; then
    echo -e "${RED}Error: WebAssembly build failed${NC}"
    exit 1
fi

# Copy WASM file to web directory
echo -e "${YELLOW}Copying WebAssembly module...${NC}"
cp "$BUILD_DIR/bin/video-editor.wasm" "$WEB_DIR/"

# Generate placeholder icons
echo -e "${YELLOW}Generating icons...${NC}"

# Create a simple SVG icon
cat > "$WEB_DIR/icon.svg" << 'EOF'
<svg width="512" height="512" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#ff4444;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#cc3333;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="512" height="512" rx="80" fill="url(#grad1)"/>
  <circle cx="256" cy="200" r="80" fill="white"/>
  <rect x="176" y="280" width="160" height="120" rx="20" fill="white"/>
  <circle cx="256" cy="340" r="20" fill="#ff4444"/>
</svg>
EOF

# Create simple test server script
echo -e "${YELLOW}Creating test server script...${NC}"
cat > "$WEB_DIR/serve.py" << 'EOF'
#!/usr/bin/env python3
import http.server
import ssl
import os
import subprocess
import sys

PORT = 8443

# Create self-signed certificate if it doesn't exist
if not os.path.exists('cert.pem') or not os.path.exists('key.pem'):
    print("Creating self-signed certificate...")
    try:
        subprocess.run([
            'openssl', 'req', '-x509', '-newkey', 'rsa:2048',
            '-keyout', 'key.pem', '-out', 'cert.pem',
            '-days', '365', '-nodes',
            '-subj', '/CN=localhost'
        ], check=True)
    except subprocess.CalledProcessError:
        print("Error: OpenSSL not found. Install OpenSSL to create certificates.")
        sys.exit(1)

# Set up HTTPS server
Handler = http.server.SimpleHTTPRequestHandler
Handler.extensions_map.update({
    '.wasm': 'application/wasm',
    '.json': 'application/manifest+json'
})

with http.server.HTTPServer(('', PORT), Handler) as httpd:
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain('cert.pem', 'key.pem')
    httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

    print(f"HTTPS Server running at https://localhost:{PORT}/mobile.html")
    print("Note: You'll need to accept the self-signed certificate in your browser")
    print("Press Ctrl+C to stop the server")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
EOF

chmod +x "$WEB_DIR/serve.py"

# Create deployment README
echo -e "${YELLOW}Creating deployment instructions...${NC}"
cat > "$WEB_DIR/README.md" << 'EOF'
# Mobile Video Recorder Deployment

## Quick Test
1. Run the test server: `python3 serve.py`
2. Open https://localhost:8443/mobile.html in your mobile browser
3. Accept the self-signed certificate
4. Grant camera and microphone permissions
5. Test recording functionality

## Production Deployment
1. Upload all files to your HTTPS web server
2. Ensure proper MIME types are set:
   - `.wasm` → `application/wasm`
   - `.json` → `application/manifest+json`
3. Enable compression for better performance
4. Set appropriate cache headers

## Files Structure
- `mobile.html` - Main mobile app interface
- `mobile-app.js` - App logic and camera handling
- `video-editor.wasm` - WebAssembly video processing module
- `manifest.json` - PWA manifest for app installation
- `sw.js` - Service worker for offline functionality
- `serve.py` - Local HTTPS test server

## Browser Requirements
- HTTPS (required for camera access)
- Modern browser with WebAssembly support
- Camera and microphone permissions

Happy recording! 🎬
EOF

# Calculate build size
BUILD_SIZE=$(du -sh "$WEB_DIR" | cut -f1)

# Build summary
echo ""
echo -e "${GREEN}✅ Build completed successfully!${NC}"
echo -e "${BLUE}📦 Build size: $BUILD_SIZE${NC}"
echo -e "${BLUE}📂 Output directory: $WEB_DIR${NC}"
echo ""
echo -e "${YELLOW}🚀 Next steps:${NC}"
echo "  1. Test locally: cd $WEB_DIR && python3 serve.py"
echo "  2. Open https://localhost:8443/mobile.html in your mobile browser"
echo "  3. Accept the self-signed certificate"
echo "  4. Grant camera permissions and test recording"
echo "  5. Add to home screen for native app experience"
echo ""
echo -e "${BLUE}📱 Features:${NC}"
echo "  ✓ PWA installable on mobile devices"
echo "  ✓ Offline camera recording"
echo "  ✓ Video export and download"
echo "  ✓ WebAssembly video processing"
echo "  ✓ Touch-optimized interface"
echo "  ✓ Background recording support"
echo ""
echo -e "${YELLOW}⚠️  Important:${NC}"
echo "  • Camera access requires HTTPS in production"
echo "  • Test on your target mobile devices"
echo "  • Consider battery optimization settings"
echo ""
echo -e "${GREEN}🎬 Happy recording!${NC}"
