#!/bin/bash

# Netlify Deployment Script for Mobile Video Recorder
# This script builds and deploys your mobile video recorder to Netlify

set -e

echo "🚀 Deploying Mobile Video Recorder to Netlify..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
SITE_NAME="mobile-video-recorder"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_DIR="$PROJECT_DIR/zig/zig-out/web"

echo -e "${BLUE}Project directory: $PROJECT_DIR${NC}"

# Check if Node.js/npm is installed
if ! command -v npm &> /dev/null; then
    echo -e "${RED}Error: Node.js/npm is not installed${NC}"
    echo "Please install Node.js from https://nodejs.org/"
    exit 1
fi

# Install Netlify CLI if not already installed
if ! command -v netlify &> /dev/null; then
    echo -e "${YELLOW}Installing Netlify CLI...${NC}"
    npm install -g netlify-cli
fi

# Build the mobile app
echo -e "${YELLOW}Building mobile app...${NC}"
if [ -f "./build-mobile-simple.sh" ]; then
    ./build-mobile-simple.sh
else
    echo -e "${RED}Error: build-mobile-simple.sh not found!${NC}"
    echo "Make sure you're running this from the video-editor directory"
    exit 1
fi

# Check if build was successful
if [ ! -d "$WEB_DIR" ]; then
    echo -e "${RED}Error: Build failed - web directory not found${NC}"
    exit 1
fi

# Navigate to web directory
cd "$WEB_DIR"

# Create _redirects file for SPA routing
echo -e "${YELLOW}Creating Netlify configuration...${NC}"
cat > _redirects << 'EOF'
# SPA fallback
/*    /mobile.html   200

# Headers for security and PWA support
/*
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  X-XSS-Protection: 1; mode=block
  Referrer-Policy: strict-origin-when-cross-origin

# PWA specific headers
/sw.js
  Cache-Control: no-cache
  Service-Worker-Allowed: /

# WASM files
/*.wasm
  Content-Type: application/wasm
  Cross-Origin-Embedder-Policy: require-corp
  Cross-Origin-Opener-Policy: same-origin

# Cache static assets
/video-editor.wasm
  Cache-Control: public, max-age=31536000, immutable

/*.js
  Cache-Control: public, max-age=31536000, immutable

/*.css
  Cache-Control: public, max-age=31536000, immutable

/*.png
  Cache-Control: public, max-age=31536000, immutable

/*.svg
  Cache-Control: public, max-age=31536000, immutable

/manifest.json
  Cache-Control: public, max-age=604800
  Content-Type: application/manifest+json
EOF

# Create netlify.toml for build settings
cat > netlify.toml << 'EOF'
[build]
  publish = "."
  command = "echo 'Static site - no build needed'"

[build.environment]
  NODE_VERSION = "18"

[[headers]]
  for = "/*.wasm"
  [headers.values]
    Content-Type = "application/wasm"
    Cross-Origin-Embedder-Policy = "require-corp"
    Cross-Origin-Opener-Policy = "same-origin"

[[headers]]
  for = "/sw.js"
  [headers.values]
    Cache-Control = "no-cache"
    Service-Worker-Allowed = "/"

[[headers]]
  for = "/*"
  [headers.values]
    X-Frame-Options = "DENY"
    X-Content-Type-Options = "nosniff"
    X-XSS-Protection = "1; mode=block"
    Referrer-Policy = "strict-origin-when-cross-origin"
    Permissions-Policy = "camera=*, microphone=*, fullscreen=*"

[[redirects]]
  from = "/*"
  to = "/mobile.html"
  status = 200

# Cache static assets
[[headers]]
  for = "/video-editor.wasm"
  [headers.values]
    Cache-Control = "public, max-age=31536000, immutable"

[[headers]]
  for = "/*.js"
  [headers.values]
    Cache-Control = "public, max-age=31536000, immutable"

[[headers]]
  for = "/*.css"
  [headers.values]
    Cache-Control = "public, max-age=31536000, immutable"

[[headers]]
  for = "/manifest.json"
  [headers.values]
    Content-Type = "application/manifest+json"
    Cache-Control = "public, max-age=604800"
EOF

# Update manifest.json with proper start URL
echo -e "${YELLOW}Updating PWA manifest...${NC}"
cat > manifest.json << 'EOF'
{
  "name": "Mobile Video Recorder",
  "short_name": "VideoRec",
  "description": "A reliable mobile video recording app that won't crash",
  "version": "1.0.0",
  "start_url": "/mobile.html",
  "display": "fullscreen",
  "orientation": "portrait-primary",
  "theme_color": "#1a1a1a",
  "background_color": "#000000",
  "scope": "/",
  "lang": "en",
  "categories": ["photo", "video", "multimedia", "productivity"],
  "icons": [
    {
      "src": "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNTEyIiBoZWlnaHQ9IjUxMiIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KICA8ZGVmcz4KICAgIDxsaW5lYXJHcmFkaWVudCBpZD0iZ3JhZDEiIHgxPSIwJSIgeTE9IjAlIiB4Mj0iMTAwJSIgeTI9IjEwMCUiPgogICAgICA8c3RvcCBvZmZzZXQ9IjAlIiBzdHlsZT0ic3RvcC1jb2xvcjojZmY0NDQ0O3N0b3Atb3BhY2l0eToxIiAvPgogICAgICA8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0eWxlPSJzdG9wLWNvbG9yOiNjYzMzMzM7c3RvcC1vcGFjaXR5OjEiIC8+CiAgICA8L2xpbmVhckdyYWRpZW50PgogIDwvZGVmcz4KICA8cmVjdCB3aWR0aD0iNTEyIiBoZWlnaHQ9IjUxMiIgcng9IjgwIiBmaWxsPSJ1cmwoI2dyYWQxKSIvPgogIDxjaXJjbGUgY3g9IjI1NiIgY3k9IjIwMCIgcj0iODAiIGZpbGw9IndoaXRlIi8+CiAgPHJlY3QgeD0iMTc2IiB5PSIyODAiIHdpZHRoPSIxNjAiIGhlaWdodD0iMTIwIiByeD0iMjAiIGZpbGw9IndoaXRlIi8+CiAgPGNpcmNsZSBjeD0iMjU2IiBjeT0iMzQwIiByPSIyMCIgZmlsbD0iI2ZmNDQ0NCIvPgo8L3N2Zz4=",
      "sizes": "512x512",
      "type": "image/svg+xml",
      "purpose": "any maskable"
    }
  ],
  "features": [
    "camera",
    "microphone",
    "storage",
    "wake-lock"
  ],
  "permissions": [
    "camera",
    "microphone",
    "storage-access",
    "wake-lock"
  ],
  "shortcuts": [
    {
      "name": "Quick Record",
      "short_name": "Record",
      "description": "Start recording immediately",
      "url": "/mobile.html?quick=true"
    }
  ],
  "display_override": ["fullscreen", "standalone"],
  "launch_handler": {
    "client_mode": "focus-existing"
  }
}
EOF

# Login to Netlify (if not already logged in)
echo -e "${YELLOW}Checking Netlify authentication...${NC}"
if ! netlify status &> /dev/null; then
    echo -e "${BLUE}Please log in to Netlify:${NC}"
    netlify login
fi

# Deploy to Netlify
echo -e "${YELLOW}Deploying to Netlify...${NC}"

# First deployment - create site
if ! netlify status &> /dev/null || ! netlify sites:list | grep -q "$SITE_NAME"; then
    echo -e "${BLUE}Creating new Netlify site...${NC}"
    netlify deploy --dir=. --open

    # Get the site URL
    SITE_URL=$(netlify status --json | grep -o '"url":"[^"]*' | cut -d'"' -f4)

    echo ""
    echo -e "${GREEN}🎉 Initial deployment successful!${NC}"
    echo -e "${BLUE}Preview URL: Check the browser that just opened${NC}"
    echo ""
    echo -e "${YELLOW}To make this the production deployment, run:${NC}"
    echo "  netlify deploy --prod --dir=$WEB_DIR"
    echo ""
    echo -e "${YELLOW}Or run the production deployment now? (y/n)${NC}"
    read -r response

    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        echo -e "${YELLOW}Deploying to production...${NC}"
        netlify deploy --prod --dir=.

        # Get production URL
        PROD_URL=$(netlify status --json | grep -o '"url":"[^"]*' | cut -d'"' -f4)

        echo ""
        echo -e "${GREEN}🚀 Production deployment successful!${NC}"
        echo -e "${BLUE}Your Mobile Video Recorder is now live at:${NC}"
        echo -e "${GREEN}$PROD_URL${NC}"
    fi
else
    # Site exists, just deploy
    echo -e "${YELLOW}Deploying to existing site...${NC}"
    netlify deploy --prod --dir=.

    # Get the site URL
    SITE_URL=$(netlify status --json | grep -o '"url":"[^"]*' | cut -d'"' -f4)

    echo ""
    echo -e "${GREEN}🚀 Deployment successful!${NC}"
    echo -e "${BLUE}Your Mobile Video Recorder is live at:${NC}"
    echo -e "${GREEN}$SITE_URL${NC}"
fi

echo ""
echo -e "${BLUE}📱 Next steps:${NC}"
echo "1. Open the URL above on your mobile device"
echo "2. Tap 'Add to Home Screen' in your browser menu"
echo "3. Grant camera and microphone permissions"
echo "4. Start recording videos that won't crash!"
echo ""
echo -e "${YELLOW}💡 Pro tips:${NC}"
echo "• The app works offline after the first visit"
echo "• Bookmark the URL for easy access"
echo "• Share the link with friends and family"
echo "• Updates automatically when you redeploy"
echo ""
echo -e "${GREEN}🎬 Happy recording!${NC}"

# Optional: Open the deployed site
read -p "Open the deployed site in your browser? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    netlify open
fi
