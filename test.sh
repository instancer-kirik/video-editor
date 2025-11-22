#!/bin/bash
set -e

# Zig WASM Video Editor - Test Launcher
# This script builds the WASM module and starts the test server

echo "🎬 Zig WASM Video Editor - Test Launcher"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default port
PORT=${1:-8080}

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed or not in PATH"
        return 1
    fi
    return 0
}

# Function to kill background processes on exit
cleanup() {
    print_warning "Cleaning up..."
    if [[ -n $SERVER_PID ]]; then
        kill $SERVER_PID 2>/dev/null || true
    fi
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Check prerequisites
print_status "Checking prerequisites..."

if ! check_command "zig"; then
    print_error "Zig compiler is required. Please install from https://ziglang.org/"
    exit 1
fi

if ! check_command "python3"; then
    print_error "Python 3 is required for the test server"
    exit 1
fi

# Check Zig version
ZIG_VERSION=$(zig version)
print_success "Found Zig version: $ZIG_VERSION"

# Build WASM module
print_status "Building WASM module..."
cd zig

if zig build wasm; then
    print_success "WASM build completed successfully"
else
    print_error "WASM build failed"
    exit 1
fi

# Check if WASM file exists
WASM_FILE="zig-out/bin/video-editor.wasm"
if [[ ! -f "$WASM_FILE" ]]; then
    print_error "WASM file not found: $WASM_FILE"
    exit 1
fi

# Get WASM file size
WASM_SIZE=$(ls -lh "$WASM_FILE" | awk '{print $5}')
print_success "WASM binary size: $WASM_SIZE"

# Go back to project root
cd ..

# Check if test files exist
if [[ ! -f "test/index.html" ]]; then
    print_error "Test HTML file not found: test/index.html"
    exit 1
fi

if [[ ! -f "test/serve.py" ]]; then
    print_error "Server script not found: test/serve.py"
    exit 1
fi

# Start the test server
print_status "Starting test server on port $PORT..."
cd test

# Check if port is already in use
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    print_warning "Port $PORT is already in use"
    ALTERNATIVE_PORT=$((PORT + 1))
    print_status "Trying alternative port $ALTERNATIVE_PORT..."
    PORT=$ALTERNATIVE_PORT

    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_error "Port $PORT is also in use. Please specify a different port:"
        print_error "Usage: $0 [port_number]"
        exit 1
    fi
fi

# Start server in background
python3 serve.py $PORT &
SERVER_PID=$!

# Wait a moment for server to start
sleep 2

# Check if server is running
if ! kill -0 $SERVER_PID 2>/dev/null; then
    print_error "Failed to start test server"
    exit 1
fi

print_success "Test server started successfully!"
echo ""
echo "🌐 Server Details:"
echo "   Port: $PORT"
echo "   URL:  http://localhost:$PORT/test/"
echo ""
echo "🧪 Test Features Available:"
echo "   📹 Camera & Video Recording"
echo "   🎨 Real-time Filters (Brightness, Contrast, Saturation)"
echo "   📝 Text Overlays with Positioning"
echo "   ⏱️  Timeline & Trimming Controls"
echo "   💾 Memory Management Monitoring"
echo "   🔧 WASM Function Testing"
echo ""
echo "🚀 Quick Test Steps:"
echo "   1. Open http://localhost:$PORT/test/ in your browser"
echo "   2. Click 'Start Camera' to access webcam"
echo "   3. Try 'Start Recording' to test video capture"
echo "   4. Adjust filter sliders for real-time effects"
echo "   5. Add text overlays with custom positioning"
echo "   6. Run WASM tests to verify functionality"
echo ""
echo "📊 Expected Performance:"
echo "   • WASM Load Time: < 100ms"
echo "   • Filter Processing: 60fps @ 720p"
echo "   • Memory Usage: < 500KB typical"
echo "   • Bundle Size: $WASM_SIZE WASM binary"
echo ""
echo "🔧 Troubleshooting:"
echo "   • Ensure camera permissions are granted"
echo "   • Use Chrome/Firefox for full WebRTC support"
echo "   • Check browser console for errors"
echo "   • Monitor the Debug section in the test page"
echo ""

# Try to open browser automatically
if command -v xdg-open &> /dev/null; then
    print_status "Attempting to open browser..."
    xdg-open "http://localhost:$PORT/test/" 2>/dev/null || true
elif command -v open &> /dev/null; then
    print_status "Attempting to open browser..."
    open "http://localhost:$PORT/test/" 2>/dev/null || true
fi

echo "Press Ctrl+C to stop the server and exit"
echo ""

# Wait for server process
wait $SERVER_PID
