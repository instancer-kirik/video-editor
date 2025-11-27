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

# Create icons directory if it doesn't exist
ICONS_DIR="$WEB_DIR/icons"
mkdir -p "$ICONS_DIR"

# Generate placeholder icons (you should replace these with actual icons)
echo -e "${YELLOW}Generating placeholder icons...${NC}"

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

# Generate PNG icons from SVG (requires ImageMagick or similar)
if command -v convert &> /dev/null; then
    echo -e "${YELLOW}Converting SVG to PNG icons...${NC}"

    # Generate different sizes
    for size in 72 96 128 144 152 192 384 512; do
        convert "$WEB_DIR/icon.svg" -resize ${size}x${size} "$WEB_DIR/icon-${size}.png"
    done

    # Create special icons
    convert "$WEB_DIR/icon.svg" -resize 192x192 "$WEB_DIR/icon-record-192.png"
    convert "$WEB_DIR/icon.svg" -resize 192x192 "$WEB_DIR/icon-settings-192.png"
    convert "$WEB_DIR/icon.svg" -resize 192x192 "$WEB_DIR/icon-close-192.png"

else
    echo -e "${YELLOW}Warning: ImageMagick not found. Creating placeholder PNG files...${NC}"

    # Create placeholder files (you should replace these with actual icons)
    for size in 72 96 128 144 152 192 384 512; do
        echo "Placeholder ${size}x${size} icon" > "$WEB_DIR/icon-${size}.png"
    done
fi

# Create screenshots placeholder
echo -e "${YELLOW}Creating placeholder screenshots...${NC}"
echo "Mobile screenshot placeholder" > "$WEB_DIR/screenshot-mobile.png"
echo "Tablet screenshot placeholder" > "$WEB_DIR/screenshot-tablet.png"

# Optimize the build
echo -e "${YELLOW}Optimizing build...${NC}"

# Minify JavaScript if uglifyjs is available
if command -v uglifyjs &> /dev/null; then
    echo -e "${BLUE}Minifying JavaScript...${NC}"
    uglifyjs "$WEB_DIR/mobile-app.js" -o "$WEB_DIR/mobile-app.min.js" -c -m
    mv "$WEB_DIR/mobile-app.min.js" "$WEB_DIR/mobile-app.js"
fi

# Minify CSS if cleancss is available
if command -v cleancss &> /dev/null; then
    echo -e "${BLUE}Minifying CSS...${NC}"
    # Extract CSS from HTML and create separate file
    grep -o '<style[^>]*>.*</style>' "$WEB_DIR/mobile.html" | sed 's/<style[^>]*>//;s/<\/style>//' > "$WEB_DIR/mobile.css"
    cleancss "$WEB_DIR/mobile.css" -o "$WEB_DIR/mobile.min.css"

    # Update HTML to use external CSS
    sed -i 's|<style[^>]*>.*</style>|<link rel="stylesheet" href="mobile.min.css">|' "$WEB_DIR/mobile.html"
fi

# Create .htaccess for proper MIME types and caching
echo -e "${YELLOW}Creating .htaccess file...${NC}"
cat > "$WEB_DIR/.htaccess" << 'EOF'
# Enable compression
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/plain
    AddOutputFilterByType DEFLATE text/html
    AddOutputFilterByType DEFLATE text/xml
    AddOutputFilterByType DEFLATE text/css
    AddOutputFilterByType DEFLATE application/xml
    AddOutputFilterByType DEFLATE application/xhtml+xml
    AddOutputFilterByType DEFLATE application/rss+xml
    AddOutputFilterByType DEFLATE application/javascript
    AddOutputFilterByType DEFLATE application/x-javascript
    AddOutputFilterByType DEFLATE application/wasm
</IfModule>

# Set correct MIME types
AddType application/wasm .wasm
AddType application/manifest+json .webmanifest
AddType application/manifest+json .json

# Cache static assets
<IfModule mod_expires.c>
    ExpiresActive on
    ExpiresByType application/wasm "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType image/png "access plus 1 month"
    ExpiresByType image/svg+xml "access plus 1 month"
    ExpiresByType application/manifest+json "access plus 1 week"
</IfModule>

# Enable HTTPS redirect (uncomment for production)
# RewriteEngine On
# RewriteCond %{HTTPS} off
# RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

# Security headers
<IfModule mod_headers.c>
    Header always set X-Content-Type-Options nosniff
    Header always set X-Frame-Options DENY
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"

    # PWA specific headers
    Header always set Service-Worker-Allowed "/"

    # Camera permissions for HTTPS
    Header always set Permissions-Policy "camera=*, microphone=*, fullscreen=*"
</IfModule>
EOF

# Create nginx configuration
echo -e "${YELLOW}Creating nginx.conf file...${NC}"
cat > "$WEB_DIR/nginx.conf" << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /path/to/web/directory;
    index mobile.html;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json
        application/wasm;

    # MIME types
    location ~* \.wasm$ {
        add_header Content-Type application/wasm;
        add_header Cross-Origin-Embedder-Policy require-corp;
        add_header Cross-Origin-Opener-Policy same-origin;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1M;
        add_header Cache-Control "public, immutable";
    }

    location /manifest.json {
        add_header Content-Type application/manifest+json;
        expires 7d;
    }

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";

    # PWA support
    location /sw.js {
        add_header Cache-Control "no-cache";
        add_header Service-Worker-Allowed "/";
    }

    # Fallback to mobile.html for SPA
    location / {
        try_files $uri $uri/ /mobile.html;
    }
}
EOF

# Create deployment script
echo -e "${YELLOW}Creating deployment script...${NC}"
cat > "$WEB_DIR/deploy.sh" << 'EOF'
#!/bin/bash

# Deployment script for Mobile Video Recorder
# Customize this script for your deployment target

echo "Deploying Mobile Video Recorder..."

# Example: Deploy to GitHub Pages
# git add .
# git commit -m "Deploy mobile video recorder"
# git push origin gh-pages

# Example: Deploy via rsync to server
# rsync -avz --delete ./ user@server:/path/to/web/directory/

# Example: Deploy to Netlify
# netlify deploy --prod --dir=.

# Example: Deploy to Vercel
# vercel --prod

echo "Deployment script template created. Customize for your needs."
EOF

chmod +x "$WEB_DIR/deploy.sh"

# Create a local test server script
echo -e "${YELLOW}Creating local test server script...${NC}"
cat > "$WEB_DIR/serve.sh" << 'EOF'
#!/bin/bash

# Local test server for Mobile Video Recorder
# Serves the app with proper HTTPS for camera access

PORT=${1:-8443}
CERT_DIR="./certs"

echo "Starting HTTPS server on port $PORT..."

# Create self-signed certificate if it doesn't exist
if [ ! -d "$CERT_DIR" ]; then
    mkdir -p "$CERT_DIR"
    openssl req -x509 -newkey rsa:4096 -keyout "$CERT_DIR/key.pem" -out "$CERT_DIR/cert.pem" -days 365 -nodes -subj "/CN=localhost"
fi

# Start server based on available tools
if command -v python3 &> /dev/null; then
    # Python 3 HTTPS server
    python3 << EOF
import http.server
import ssl
import socketserver

PORT = $PORT

Handler = http.server.SimpleHTTPRequestHandler
Handler.extensions_map.update({
    '.wasm': 'application/wasm',
    '.json': 'application/manifest+json'
})

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain('$CERT_DIR/cert.pem', '$CERT_DIR/key.pem')
    httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

    print(f"Serving at https://localhost:{PORT}")
    print("Note: You'll need to accept the self-signed certificate")
    httpd.serve_forever()
EOF

elif command -v node &> /dev/null; then
    # Node.js HTTPS server
    cat > server.js << 'JSEOF'
const https = require('https');
const fs = require('fs');
const path = require('path');

const options = {
    key: fs.readFileSync('./certs/key.pem'),
    cert: fs.readFileSync('./certs/cert.pem')
};

const mimeTypes = {
    '.html': 'text/html',
    '.js': 'application/javascript',
    '.css': 'text/css',
    '.json': 'application/manifest+json',
    '.wasm': 'application/wasm',
    '.png': 'image/png',
    '.svg': 'image/svg+xml'
};

https.createServer(options, (req, res) => {
    let filePath = '.' + req.url;
    if (filePath === './') filePath = './mobile.html';

    const extname = path.extname(filePath).toLowerCase();
    const contentType = mimeTypes[extname] || 'application/octet-stream';

    fs.readFile(filePath, (error, content) => {
        if (error) {
            if (error.code === 'ENOENT') {
                res.writeHead(404);
                res.end('File not found');
            } else {
                res.writeHead(500);
                res.end('Server error: ' + error.code);
            }
        } else {
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(content, 'utf-8');
        }
    });
}).listen(PORT, () => {
    console.log(`Server running at https://localhost:${PORT}/`);
});
JSEOF

    node server.js
    rm server.js

else
    echo "Error: Neither Python 3 nor Node.js found. Please install one to run the test server."
    exit 1
fi
EOF

chmod +x "$WEB_DIR/serve.sh"

# Calculate build size
echo -e "${YELLOW}Calculating build size...${NC}"
BUILD_SIZE=$(du -sh "$WEB_DIR" | cut -f1)

# Build summary
echo ""
echo -e "${GREEN}✅ Build completed successfully!${NC}"
echo -e "${BLUE}📦 Build size: $BUILD_SIZE${NC}"
echo -e "${BLUE}📂 Output directory: $WEB_DIR${NC}"
echo ""
echo -e "${YELLOW}🚀 Next steps:${NC}"
echo "  1. Test locally: cd $WEB_DIR && ./serve.sh"
echo "  2. Open https://localhost:8443 in your mobile browser"
echo "  3. Accept the self-signed certificate"
echo "  4. Add to home screen for native app experience"
echo "  5. Deploy: cd $WEB_DIR && ./deploy.sh"
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
echo "  • Replace placeholder icons with real ones"
echo "  • Test thoroughly on target devices"
echo "  • Consider battery optimization settings"
echo ""
echo -e "${GREEN}🎬 Happy recording!${NC}"
