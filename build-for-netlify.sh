#!/bin/bash

# Netlify-compatible build script for Mobile Video Recorder
# This script works without needing Zig on Netlify's build servers

set -e

echo "🚀 Building Mobile Video Recorder for Netlify..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Check if we're running on Netlify
if [ "$NETLIFY" = "true" ]; then
    echo -e "${BLUE}Running on Netlify build servers${NC}"

    # Check if pre-built files exist
    if [ ! -f "zig/zig-out/web/mobile.html" ] || [ ! -f "zig/zig-out/web/video-editor.wasm" ]; then
        echo -e "${RED}Error: Pre-built files not found!${NC}"
        echo "Please build locally first and commit the zig/zig-out/web directory:"
        echo "  ./build-mobile-simple.sh"
        echo "  git add zig/zig-out/web"
        echo "  git commit -m 'Add pre-built web assets'"
        echo "  git push"
        exit 1
    fi

    echo -e "${GREEN}Using pre-built files${NC}"

    # Ensure proper permissions
    chmod +x zig/zig-out/web/serve.py || true

    echo -e "${GREEN}✅ Build complete - using pre-built assets${NC}"

else
    echo -e "${BLUE}Running locally - building from source${NC}"

    # Check if zig is installed locally
    if ! command -v zig &> /dev/null; then
        echo -e "${RED}Error: Zig is not installed locally${NC}"
        echo "Please install Zig from https://ziglang.org/"
        exit 1
    fi

    # Navigate to zig directory and build
    cd zig

    echo -e "${YELLOW}Building WebAssembly module...${NC}"
    zig build mobile --summary all

    # Copy WASM file to web directory if needed
    if [ -f "zig-out/bin/video-editor.wasm" ]; then
        cp zig-out/bin/video-editor.wasm zig-out/web/
    fi

    cd ..

    echo -e "${GREEN}✅ Local build complete${NC}"
fi

# Verify required files exist
WEB_DIR="zig/zig-out/web"
REQUIRED_FILES=(
    "mobile.html"
    "mobile-app.js"
    "manifest.json"
    "sw.js"
    "video-editor.wasm"
)

echo -e "${YELLOW}Verifying required files...${NC}"
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$WEB_DIR/$file" ]; then
        echo -e "${RED}Error: Missing required file: $file${NC}"
        exit 1
    else
        echo -e "${GREEN}✓ $file${NC}"
    fi
done

# Calculate and display build size
if [ -d "$WEB_DIR" ]; then
    BUILD_SIZE=$(du -sh "$WEB_DIR" | cut -f1)
    echo -e "${BLUE}📦 Build size: $BUILD_SIZE${NC}"
fi

# Create a build info file
cat > "$WEB_DIR/build-info.json" << EOF
{
  "buildTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "buildEnvironment": "${NETLIFY:-local}",
  "version": "1.0.0",
  "files": [
$(ls "$WEB_DIR" | sed 's/.*/"&"/' | paste -sd ',' -)
  ]
}
EOF

echo -e "${GREEN}🎉 Build successful!${NC}"

if [ "$NETLIFY" = "true" ]; then
    echo -e "${BLUE}📱 Your Mobile Video Recorder will be available at your Netlify URL${NC}"
    echo -e "${BLUE}Add to home screen on mobile for native app experience${NC}"
else
    echo -e "${BLUE}📁 Built files are in: $WEB_DIR${NC}"
    echo -e "${BLUE}Deploy with: git add $WEB_DIR && git commit && git push${NC}"
fi
