#!/bin/bash

# Professional Video Editor Workspace Launcher
# This script starts the video editor with the new professional workspace interface

set -e

echo "🎬 Starting Professional Video Editor Workspace..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if WASM file exists
if [ ! -f "video-editor.wasm" ]; then
    echo "❌ WASM file not found. Building..."

    # Try to build WASM if zig directory exists
    if [ -d "../zig" ]; then
        echo "🔨 Building WASM binary..."
        cd ../zig
        zig build wasm

        # Copy WASM file to test directory
        if [ -f "zig-out/bin/video-editor.wasm" ]; then
            cp zig-out/bin/video-editor.wasm ../test/
            echo "✅ WASM binary copied to test directory"
        else
            echo "❌ Failed to build WASM binary"
            exit 1
        fi

        cd ../test
    else
        echo "❌ Zig source directory not found"
        exit 1
    fi
fi

# Check if workspace.html exists
if [ ! -f "workspace.html" ]; then
    echo "❌ workspace.html not found"
    exit 1
fi

# Function to find available port
find_port() {
    local port=$1
    while lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; do
        port=$((port + 1))
    done
    echo $port
}

# Find available port starting from 8080
PORT=$(find_port 8080)

echo "🚀 Starting development server on port $PORT..."

# Kill any existing servers on the chosen port
lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
sleep 1

echo "📡 Server starting..."
echo "🌐 Opening http://localhost:$PORT/workspace.html"
echo "📝 Professional workspace with timeline, media library, and clip management"
echo ""
echo "✨ NEW FEATURES:"
echo "  • 🎥 Auto-add recordings to timeline"
echo "  • 🖼️ Real video thumbnails"
echo "  • 🎯 Drag & resize timeline clips"
echo "  • 💫 Visual selection feedback"
echo "  • 📂 Double-click to add clips"
echo "  • 🎨 Real-time video filters"
echo "  • 📝 Text overlays"
echo "  • 💾 Project save/load"
echo ""
echo "🎬 WORKFLOW:"
echo "  1. Click 🎥 Record → Stops → Auto-adds to timeline"
echo "  2. Import files → Double-click → Adds to timeline"
echo "  3. Click timeline clips to select & edit"
echo "  4. Drag clips to move, drag edges to resize"
echo ""
echo "Press Ctrl+C to stop the server"
echo "----------------------------------------"

# Function to open browser
open_browser() {
    local url=$1
    if command -v xdg-open &> /dev/null; then
        xdg-open "$url" &
    elif command -v open &> /dev/null; then
        open "$url" &
    elif command -v firefox &> /dev/null; then
        firefox "$url" &
    elif command -v google-chrome &> /dev/null; then
        google-chrome "$url" &
    else
        echo "💡 Manual: Open $url in your browser"
    fi
}

# Start server with simple Python server (no custom handlers)
if command -v python3 &> /dev/null; then
    echo "📡 Using Python 3 HTTP server on port $PORT"
    echo "✅ Server running at http://localhost:$PORT"
    echo "🎬 Workspace ready at /workspace.html"

    # Open browser after short delay
    (sleep 3 && open_browser "http://localhost:$PORT/workspace.html") &

    # Use simple HTTP server without custom handlers
    python3 -m http.server $PORT

elif command -v python &> /dev/null; then
    echo "📡 Using Python 2 HTTP server on port $PORT"
    echo "✅ Server running at http://localhost:$PORT"
    echo "🎬 Workspace ready at /workspace.html"
    (sleep 3 && open_browser "http://localhost:$PORT/workspace.html") &
    python -m SimpleHTTPServer $PORT

elif command -v node &> /dev/null && [ -f "server.js" ]; then
    echo "📡 Using Node.js Express server on port $PORT"
    echo "✅ Server running at http://localhost:$PORT"
    echo "🎬 Workspace ready at /workspace.html"
    (sleep 3 && open_browser "http://localhost:$PORT/workspace.html") &
    PORT=$PORT node server.js

else
    echo "❌ No suitable HTTP server found"
    echo "Please install Python 3, Python 2, or Node.js to run the development server"
    echo ""
    echo "🔧 Install options:"
    echo "  • Python 3: apt install python3 (Ubuntu) | brew install python3 (macOS)"
    echo "  • Node.js: https://nodejs.org/en/download/"
    echo ""
    echo "🌐 Alternative: You can serve the files manually:"
    echo "  • Copy video-editor/test/ to your web server"
    echo "  • Open workspace.html in your browser"
    echo "  • Make sure WASM files are served with proper MIME type"
    echo ""
    echo "🚀 Quick start:"
    echo "  cd $(pwd)"
    echo "  python3 -m http.server 8080"
    echo "  # Then open: http://localhost:8080/workspace.html"
    exit 1
fi
