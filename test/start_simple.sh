#!/bin/bash

echo "🎬 Simple Video Editor Launcher"
echo "================================"

# Get script directory
cd "$(dirname "$0")"

# Check required files
if [ ! -f "workspace.html" ]; then
    echo "❌ workspace.html not found"
    exit 1
fi

if [ ! -f "video-editor.wasm" ]; then
    echo "❌ video-editor.wasm not found - run 'zig build wasm' first"
    exit 1
fi

# Find available port
PORT=8080
while netstat -an | grep ":$PORT " > /dev/null 2>&1; do
    PORT=$((PORT + 1))
done

echo "🌐 Starting server on port $PORT..."
echo ""
echo "🎯 OPEN THIS URL:"
echo "   http://localhost:$PORT/workspace.html"
echo ""
echo "🎬 Professional Video Editor Features:"
echo "   • Record video → Auto-adds to timeline"
echo "   • Import files → Double-click to add"
echo "   • Click timeline clips to select"
echo "   • Drag clips to move, edges to resize"
echo "   • Real-time filters & effects"
echo ""
echo "Press Ctrl+C to stop"
echo "================================"

# Simple Python server
if command -v python3 >/dev/null 2>&1; then
    python3 -m http.server $PORT
elif command -v python >/dev/null 2>&1; then
    python -m SimpleHTTPServer $PORT
else
    echo "❌ Python not found. Please install Python 3"
    echo ""
    echo "Ubuntu/Debian: sudo apt install python3"
    echo "macOS: brew install python3"
    echo "Windows: Download from python.org"
    exit 1
fi
