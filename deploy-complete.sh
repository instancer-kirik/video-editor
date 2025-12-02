#!/bin/bash

# Complete Web App Deployment Script
# This script builds and deploys the complete video editor web app to Netlify

set -e  # Exit on any error

echo "🚀 Deploying Complete Video Editor Web App..."

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
DEPLOY_DIR="$PROJECT_DIR/netlify-deploy"

echo -e "${BLUE}Project directory: $PROJECT_DIR${NC}"

# Check if zig is installed
if ! command -v zig &> /dev/null; then
    echo -e "${RED}Error: Zig is not installed or not in PATH${NC}"
    echo "Please install Zig from https://ziglang.org/"
    exit 1
fi

# Check if netlify CLI is installed
if ! command -v netlify &> /dev/null; then
    echo -e "${YELLOW}Warning: Netlify CLI not found. Install with: npm install -g netlify-cli${NC}"
    NETLIFY_AVAILABLE=false
else
    NETLIFY_AVAILABLE=true
fi

# Navigate to zig directory
cd "$ZIG_DIR"

# Clean and build
echo -e "${YELLOW}Building complete web app...${NC}"
if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
fi

zig build mobile --summary all

# Verify build was successful
if [ ! -f "$WEB_DIR/video-editor.wasm" ]; then
    echo -e "${RED}Error: WASM build failed${NC}"
    exit 1
fi

if [ ! -f "$WEB_DIR/mobile-app.js" ]; then
    echo -e "${RED}Error: JavaScript files not found${NC}"
    exit 1
fi

# Create deployment directory
echo -e "${YELLOW}Preparing deployment directory...${NC}"
if [ -d "$DEPLOY_DIR" ]; then
    rm -rf "$DEPLOY_DIR"
fi
mkdir -p "$DEPLOY_DIR"

# Copy all web files
echo -e "${YELLOW}Copying web files...${NC}"
cp -r "$WEB_DIR"/* "$DEPLOY_DIR/"

# Remove unnecessary files for deployment
echo -e "${YELLOW}Cleaning up deployment files...${NC}"
rm -f "$DEPLOY_DIR"/key.pem
rm -f "$DEPLOY_DIR"/cert.pem
rm -f "$DEPLOY_DIR"/serve.py
rm -f "$DEPLOY_DIR"/README.md
rm -f "$DEPLOY_DIR"/build-info.json

# Create Netlify configuration
echo -e "${YELLOW}Creating Netlify configuration...${NC}"
cat > "$DEPLOY_DIR/_headers" << 'EOF'
# Headers for proper WASM loading and security
/*
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  X-XSS-Protection: 1; mode=block
  Referrer-Policy: strict-origin-when-cross-origin

# WASM files
/*.wasm
  Content-Type: application/wasm
  Cross-Origin-Embedder-Policy: require-corp
  Cross-Origin-Opener-Policy: same-origin

# Cache static assets
/video-editor.wasm
  Cache-Control: public, max-age=2592000

/manifest.json
  Content-Type: application/manifest+json
  Cache-Control: public, max-age=604800

/sw.js
  Cache-Control: no-cache
  Service-Worker-Allowed: /

# Camera permissions for PWA
/*
  Permissions-Policy: camera=*, microphone=*, fullscreen=*
EOF

# Create redirects for SPA
cat > "$DEPLOY_DIR/_redirects" << 'EOF'
# SPA fallback
/mobile /mobile.html 200
/app /mobile.html 200
/* /mobile.html 200
EOF

# Create netlify.toml
cat > "$DEPLOY_DIR/netlify.toml" << 'EOF'
[build]
  publish = "."

[[headers]]
  for = "/*.wasm"
  [headers.values]
    Content-Type = "application/wasm"
    Cross-Origin-Embedder-Policy = "require-corp"
    Cross-Origin-Opener-Policy = "same-origin"

[[headers]]
  for = "/manifest.json"
  [headers.values]
    Content-Type = "application/manifest+json"

[[headers]]
  for = "/*"
  [headers.values]
    X-Frame-Options = "DENY"
    X-Content-Type-Options = "nosniff"
    X-XSS-Protection = "1; mode=block"
    Referrer-Policy = "strict-origin-when-cross-origin"
    Permissions-Policy = "camera=*, microphone=*, fullscreen=*"

[[redirects]]
  from = "/mobile"
  to = "/mobile.html"
  status = 200

[[redirects]]
  from = "/app"
  to = "/mobile.html"
  status = 200

[[redirects]]
  from = "/*"
  to = "/mobile.html"
  status = 200
EOF

# Calculate deployment size
DEPLOY_SIZE=$(du -sh "$DEPLOY_DIR" | cut -f1)

echo ""
echo -e "${GREEN}✅ Build completed successfully!${NC}"
echo -e "${BLUE}📦 Total size: $DEPLOY_SIZE${NC}"
echo -e "${BLUE}📂 Deployment directory: $DEPLOY_DIR${NC}"

# List key files
echo -e "${YELLOW}📋 Key files included:${NC}"
echo "  📱 mobile.html ($(du -sh "$DEPLOY_DIR/mobile.html" | cut -f1))"
echo "  🖥️  index.html ($(du -sh "$DEPLOY_DIR/index.html" | cut -f1))"
echo "  📦 video-editor.wasm ($(du -sh "$DEPLOY_DIR/video-editor.wasm" | cut -f1))"
echo "  🎬 mobile-app.js ($(du -sh "$DEPLOY_DIR/mobile-app.js" | cut -f1))"
echo "  📷 camera.js ($(du -sh "$DEPLOY_DIR/camera.js" | cut -f1))"
echo "  ✂️  editor.js ($(du -sh "$DEPLOY_DIR/editor.js" | cut -f1))"
echo "  🔧 bindings.js ($(du -sh "$DEPLOY_DIR/bindings.js" | cut -f1))"
echo "  🎨 styles.css ($(du -sh "$DEPLOY_DIR/styles.css" | cut -f1))"
echo "  📋 manifest.json ($(du -sh "$DEPLOY_DIR/manifest.json" | cut -f1))"
echo "  ⚙️  sw.js ($(du -sh "$DEPLOY_DIR/sw.js" | cut -f1))"

echo ""
echo -e "${YELLOW}🚀 Deployment Options:${NC}"
echo ""

if [ "$NETLIFY_AVAILABLE" = true ]; then
    echo -e "${GREEN}Option 1: Deploy with Netlify CLI${NC}"
    echo "  cd $DEPLOY_DIR"
    echo "  netlify deploy --prod --dir=."
    echo ""
fi

echo -e "${GREEN}Option 2: Manual Netlify Drag & Drop${NC}"
echo "  1. Open https://app.netlify.com/"
echo "  2. Drag the entire contents of: $DEPLOY_DIR"
echo "  3. Your app will be live at: https://[random-name].netlify.app"
echo ""

echo -e "${GREEN}Option 3: GitHub Pages${NC}"
echo "  1. Push contents to a 'gh-pages' branch"
echo "  2. Enable GitHub Pages in repository settings"
echo ""

echo -e "${GREEN}Option 4: Vercel${NC}"
echo "  cd $DEPLOY_DIR"
echo "  vercel --prod"
echo ""

echo -e "${BLUE}💡 Quick Test Locally:${NC}"
echo "  cd $DEPLOY_DIR"
echo "  python3 -m http.server 8000 --bind 0.0.0.0"
echo "  Open: http://localhost:8000/mobile.html"
echo ""

echo -e "${YELLOW}⚠️  Important Notes:${NC}"
echo "  • Camera access requires HTTPS in production"
echo "  • The mobile.html is the main app entry point"
echo "  • WASM loading requires proper Content-Type headers"
echo "  • PWA features work best with HTTPS"
echo ""

# Auto-deploy with Netlify CLI if available and requested
read -p "Deploy to Netlify now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] && [ "$NETLIFY_AVAILABLE" = true ]; then
    echo -e "${YELLOW}Deploying to Netlify...${NC}"
    cd "$DEPLOY_DIR"
    netlify deploy --prod --dir=.
    echo -e "${GREEN}🎉 Deployment complete!${NC}"
else
    echo -e "${BLUE}Manual deployment ready in: $DEPLOY_DIR${NC}"
fi

echo -e "${GREEN}🎬 Happy recording!${NC}"
