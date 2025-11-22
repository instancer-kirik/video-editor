#!/bin/bash

# WASM Video Editor - Build and Serve Script
# This script builds the WASM module and starts a development server

set -e

echo "🎬 WASM Video Editor Build Script"
echo "=================================="

# Check if zig is available
if ! command -v zig &> /dev/null; then
    echo "❌ Error: Zig compiler not found. Please install Zig first."
    echo "   Visit: https://ziglang.org/download/"
    exit 1
fi

# Check if python3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 not found. Please install Python 3."
    exit 1
fi

echo "✅ Dependencies found"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -f *.wasm *.wasm.o

# Build WASM module
echo "🔨 Building WASM module..."
zig build-exe \
    -target wasm32-freestanding \
    -fno-entry \
    -rdynamic \
    --name video-editor \
    src/main.zig

if [ $? -eq 0 ]; then
    echo "✅ WASM build successful!"
    echo "📦 Output: video-editor.wasm ($(du -h video-editor.wasm | cut -f1))"
else
    echo "❌ WASM build failed!"
    exit 1
fi

# Find available port
PORT=8080
while lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; do
    PORT=$((PORT + 1))
done

echo "🚀 Starting development server on port $PORT..."
echo "📡 Open your browser to: http://localhost:$PORT"
echo "⚡ Press Ctrl+C to stop the server"
echo ""
echo "💡 Tips:"
echo "   • Ctrl+R to start recording"
echo "   • Ctrl+S to stop recording"
echo "   • Ctrl+C to start camera"
echo "   • Ctrl+T to run tests"
echo "   • Space to play/pause timeline"
echo "   • + to add clips"
echo ""

# Start HTTP server
python3 -m http.server $PORT
