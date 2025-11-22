# 🎬 Zig WASM Video Editor - Testing Guide

A comprehensive test environment for the TikTok-style video editor built with Zig WebAssembly.

## 🚀 Quick Start

### Option 1: Python Server (Recommended)
```bash
cd video-editor/test
python3 serve.py
# Opens at http://localhost:8080/test/
```

### Option 2: Node.js Server
```bash
cd video-editor/test
npm install
npm start
# Opens at http://localhost:8080/test/
```

### Option 3: Manual Build + Serve
```bash
# Build WASM
cd video-editor/zig
zig build

# Serve (any method)
cd ../test
python3 -m http.server 8080
```

## 📋 What's Included

### 🎯 Core Test Page (`index.html`)
- **Complete WASM testing environment** with real-time UI
- **Camera integration** with MediaDevices API
- **Video recording** with MediaRecorder
- **Real-time filters** applied via WASM pixel processing
- **Text overlay system** with positioning controls
- **Timeline/trimming interface**
- **Memory management** monitoring
- **Error logging** and debug console

### 🖥️ Server Options
- **`serve.py`** - Simple Python HTTP server with WASM support
- **`server.js`** - Express.js server with advanced features
- **`package.json`** - Node.js project configuration

## 🧪 Test Features

### 📹 Video Recording & Camera
- ✅ Camera access via `getUserMedia`
- ✅ Resolution control (1280x720 @ 30fps)
- ✅ Recording state management
- ✅ Real-time preview
- ✅ Device enumeration and switching

### 🎨 Real-time Filters
- ✅ Brightness adjustment (0.0 - 2.0)
- ✅ Contrast control (0.0 - 2.0)  
- ✅ Saturation tuning (0.0 - 2.0)
- ✅ Pixel-level processing in WASM
- ✅ Live preview with canvas rendering

### 📝 Text Overlays
- ✅ Dynamic text positioning (X/Y coordinates)
- ✅ Font size control (12-72px)
- ✅ Color picker integration
- ✅ Multiple overlay support (up to 16)
- ✅ Add/remove overlay management

### ⏱️ Timeline & Export
- ✅ Timeline scrubbing (0-10 seconds)
- ✅ Range selection and trimming
- ✅ Current time tracking
- ✅ Export functionality preparation

### 💾 WASM Integration
- ✅ Memory management (1MB static buffer)
- ✅ JavaScript ↔ WASM interop (30+ functions)
- ✅ Error handling and reporting
- ✅ Performance monitoring

## 🔧 Technical Architecture

### WASM Exports Available
```javascript
// Core functionality
init_video_editor()
start_recording() → i32
stop_recording() → i32
is_recording() → i32

// Video processing
process_frame(data_ptr, width, height)
apply_brightness(value: f32)
apply_contrast(value: f32)
apply_saturation(value: f32)

// Text overlays
add_text_overlay(x, y, text_ptr, len, font_size, color) → i32
remove_text_overlay(index) → i32
clear_text_overlays()
get_text_overlay_count() → usize

// Timeline
set_timeline_range(start: f32, end: f32)
set_current_time(time: f32)
get_current_time() → f32

// Memory management
alloc(size: usize) → [*]u8
reset_memory()
get_memory_usage() → usize

// Error handling
get_last_error() → [*]const u8
get_last_error_len() → usize

// Test functions
test_basic_math() → i32
test_memory() → i32
test_video_state() → i32
```

### File Structure
```
test/
├── index.html          # Main test interface
├── serve.py           # Python HTTP server
├── server.js          # Node.js Express server
├── package.json       # NPM configuration
└── README.md          # This file

../zig/
├── zig-out/bin/video-editor.wasm  # Built WASM binary (689KB)
├── src/main.zig                   # WASM exports
├── src/web.zig                    # Web API bindings
└── src/components/                # Video editor components
```

## 🎯 Testing Checklist

### Basic Functionality
- [ ] WASM module loads successfully
- [ ] Math functions work (`8 = 5 + 3`)
- [ ] Memory allocation/deallocation
- [ ] Error reporting system

### Camera & Recording
- [ ] Camera permission granted
- [ ] Video stream displays in preview
- [ ] Recording state toggles properly
- [ ] Resolution settings applied
- [ ] Frame rate monitoring

### Video Processing
- [ ] Brightness filter responds to slider
- [ ] Contrast adjustment works
- [ ] Saturation changes visible
- [ ] Filter reset functionality
- [ ] Real-time processing performance

### Text Overlays
- [ ] Text overlays add at correct positions
- [ ] Font size changes apply
- [ ] Color picker affects text color
- [ ] Multiple overlays supported
- [ ] Clear all overlays function

### Timeline & Export
- [ ] Timeline scrubbing updates current time
- [ ] Range selection works
- [ ] Export preparation completes
- [ ] Memory usage stays within bounds

## 🐛 Troubleshooting

### WASM Loading Issues
```
❌ Failed to load WASM: 404
```
**Solution**: Ensure `zig build` completed successfully and WASM file exists at `../zig/zig-out/bin/video-editor.wasm`

### Camera Permission Denied
```
❌ Camera error: NotAllowedError
```
**Solution**: 
1. Ensure HTTPS or localhost
2. Check browser permissions
3. Try different browser

### Memory Errors
```
❌ Cannot allocate memory
```
**Solution**: Reset memory buffer with "Reset Memory" button or refresh page

### Filter Performance Issues
```
⚠️ Frame processing slow
```
**Solution**:
1. Lower resolution in camera constraints
2. Reduce filter intensity
3. Check browser performance tools

## 📊 Performance Metrics

### Expected Performance
- **WASM Load Time**: < 100ms
- **Camera Initialization**: < 2 seconds
- **Filter Processing**: 60fps @ 720p
- **Memory Usage**: < 500KB typical
- **Bundle Size**: 689KB WASM + 8KB HTML/JS

### Browser Compatibility
- ✅ Chrome 88+ (full support)
- ✅ Firefox 84+ (full support) 
- ✅ Safari 14+ (WebRTC limitations)
- ✅ Edge 88+ (full support)
- ⚠️ Mobile browsers (limited camera switching)

## 🔮 Advanced Testing

### Custom WASM Module Testing
```javascript
// Direct WASM memory access
const memory = wasmModule.memory;
const buffer = new Uint8Array(memory.buffer);

// Custom filter development
const customFilter = (imageData) => {
    // Your filter logic here
    wasmModule.process_custom_frame(imageData);
};
```

### Performance Profiling
1. Open Chrome DevTools
2. Go to Performance tab
3. Record while applying filters
4. Analyze WASM execution time

### Memory Leak Detection
1. Monitor "Memory Usage" counter
2. Apply filters repeatedly
3. Check for memory growth
4. Use browser Memory tab for detailed analysis

## 🚀 Next Steps

After successful testing:

1. **Production Build**: Optimize WASM with `-O ReleaseFast`
2. **PWA Integration**: Add service worker for offline support
3. **Mobile Optimization**: Implement touch gestures and responsive design
4. **Advanced Features**: Add more filters, effects, and export formats
5. **Backend Integration**: Connect to video processing pipeline

## 📞 Support

If you encounter issues:

1. Check browser console for JavaScript errors
2. Monitor the Debug & Errors section in the test page
3. Verify WASM binary exists and is accessible
4. Test with different browsers
5. Check server MIME type configuration for `.wasm` files

---

**Built with ❤️ using Zig + WebAssembly**

*This testing environment provides comprehensive coverage of the video editor's core functionality and serves as a foundation for further development.*