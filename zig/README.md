# 🎬 WASM Video Editor

A high-performance video editor built with WebAssembly (WASM) using Zig. This editor provides real-time video processing, timeline management, and clip editing capabilities directly in your web browser.

## ✨ Features

### Core Functionality
- **Real-time Video Processing**: Hardware-accelerated video effects using WASM
- **Camera Integration**: Live camera feed with WebRTC support
- **Timeline Management**: Drag-and-drop timeline with clip snapping
- **Recording Capabilities**: Record from camera with WebM format
- **Memory Management**: Efficient WASM memory allocation and cleanup

### Video Effects
- **Brightness Control**: Real-time brightness adjustment (0.0 - 3.0)
- **Contrast Enhancement**: Dynamic contrast control (0.0 - 3.0)
- **Saturation Adjustment**: Color saturation modification (0.0 - 3.0)
- **Frame Processing**: Per-pixel RGBA manipulation

### Timeline Features
- **Multi-Clip Support**: Up to 32 clips per timeline
- **Clip Types**: Camera feeds, recordings, and imported media
- **Playback Control**: Play/pause with real-time scrubbing
- **Time Snapping**: Automatic alignment to clip boundaries
- **Visual Timeline**: Color-coded clips with duration display

## 🚀 Quick Start

### Prerequisites
- **Zig Compiler**: Version 0.11.0 or later ([Download](https://ziglang.org/download/))
- **Python 3**: For development server
- **Modern Browser**: Chrome 88+, Firefox 85+, Safari 14+

### Build and Run

1. **Clone and Navigate**:
   ```bash
   cd video-editor/zig
   ```

2. **Build and Serve**:
   ```bash
   ./build-and-serve.sh
   ```

3. **Open Browser**:
   Navigate to `http://localhost:8080` (or the port shown in terminal)

### Manual Build

```bash
# Build WASM module
zig build-exe -target wasm32-freestanding -fno-entry -rdynamic --name video-editor src/main.zig

# Start server
python3 -m http.server 8080
```

## 🎯 Usage Guide

### Getting Started

1. **Initialize WASM**: Click "Initialize WASM" button
2. **Start Camera**: Click "Start Camera" to enable webcam
3. **Add Clips**: Use "+" button or press `+` key to add clips
4. **Control Playback**: Use play/pause buttons or spacebar

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Space` | Play/Pause timeline |
| `+` or `=` | Add new clip |
| `Ctrl+C` | Start camera |
| `Ctrl+R` | Start recording |
| `Ctrl+S` | Stop recording |
| `Ctrl+T` | Run WASM tests |

### Camera Recording

1. **Enable Camera**: Click "Start Camera" button
2. **Begin Recording**: Click "Start Recording" 
3. **Stop Recording**: Click "Stop Recording"
4. **Auto-Add**: Recordings automatically added to timeline

### Timeline Controls

- **Scrubbing**: Click anywhere on timeline to jump to time
- **Clip Management**: View clips in sidebar, remove with ✕ button
- **Range Setting**: Set custom timeline duration (default: 30s)
- **Visual Feedback**: Color-coded clips (green=camera, red=recording)

## 🛠 Architecture

### WASM Module (`src/main.zig`)

```
Core Components:
├── Memory Management (1MB static buffer)
├── Video Editor State (resolution, effects, etc.)
├── Timeline System (clips, playback, snapping)
├── Effect Processing (brightness, contrast, saturation)
└── Clip Management (add, remove, query)
```

### JavaScript Interface (`index.html`)

```
Frontend Components:
├── WASM Loader and Bindings
├── Camera/WebRTC Integration  
├── Timeline UI and Interaction
├── Effect Controls and Sliders
└── Clip Management Interface
```

### Key Exports

| Function | Purpose |
|----------|---------|
| `init_video_editor()` | Initialize editor state |
| `start_recording()` | Begin video recording |
| `add_clip(start, duration, name, type)` | Add clip to timeline |
| `process_frame(data, width, height)` | Apply effects to frame |
| `set_timeline_range(start, end)` | Set timeline bounds |
| `apply_brightness(value)` | Real-time brightness |

## 📊 Performance

### Memory Usage
- **Static Buffer**: 1MB pre-allocated
- **Clip Storage**: ~100 bytes per clip
- **Frame Processing**: Zero-copy when possible
- **Memory Reset**: `reset_memory()` function available

### Optimization Features
- **WASM Performance**: Near-native speed for video processing
- **Efficient Algorithms**: Linear interpolation for effects
- **Minimal Allocations**: Stack-based processing where possible
- **Browser Integration**: Hardware-accelerated canvas rendering

## 🧪 Testing

### Automated Tests
The WASM module includes built-in test functions:

```javascript
// Run all tests
runTests();

// Individual test functions
wasmInstance.exports.test_basic_math();    // Returns: 8
wasmInstance.exports.test_memory();        // Returns: 1 (success)
wasmInstance.exports.test_video_state();   // Returns: 1 (success)
```

### Manual Testing
1. **Camera Test**: Verify webcam access and display
2. **Recording Test**: Record 5-second clip, verify playback
3. **Effects Test**: Adjust sliders, observe real-time changes
4. **Timeline Test**: Add multiple clips, test playback
5. **Memory Test**: Monitor memory usage during operation

## 🔧 Development

### Project Structure
```
zig/
├── src/
│   └── main.zig          # WASM module source
├── index.html            # Web interface
├── build-and-serve.sh    # Build script
├── README.md             # This file
└── video-editor.wasm     # Compiled output
```

### Adding Features

1. **New WASM Function**:
   ```zig
   export fn my_function(param: f32) i32 {
       // Implementation
       return 0;
   }
   ```

2. **JavaScript Binding**:
   ```javascript
   function myFeature(value) {
       if (wasmInstance.exports.my_function) {
           return wasmInstance.exports.my_function(value);
       }
   }
   ```

### Debugging
- **Browser DevTools**: Console shows detailed logs
- **WASM Inspector**: Use browser WASM debugging tools
- **Error Handling**: Check `get_last_error()` for WASM errors
- **Memory Monitor**: Use `get_memory_usage()` to track allocations

## 🌐 Browser Compatibility

| Browser | Version | Status | Notes |
|---------|---------|---------|--------|
| Chrome | 88+ | ✅ Full Support | Recommended |
| Firefox | 85+ | ✅ Full Support | Good performance |
| Safari | 14+ | ✅ Full Support | iOS support |
| Edge | 88+ | ✅ Full Support | Chromium-based |

### Required Features
- WebAssembly support
- WebRTC/getUserMedia
- MediaRecorder API
- Canvas 2D Context
- ES6 Modules

## 🚨 Troubleshooting

### Common Issues

**WASM Loading Failed**
- Ensure proper MIME types: `application/wasm`
- Check browser console for detailed errors
- Verify file exists and is accessible

**Camera Not Working**
- Grant camera permissions in browser
- Check HTTPS requirement for getUserMedia
- Verify camera not used by other applications

**Performance Issues**
- Monitor memory usage with built-in tools
- Reduce video resolution for better performance
- Clear clips periodically to free memory

**Build Errors**
- Verify Zig version compatibility
- Check file permissions on build script
- Ensure all source files present

### Debug Commands

```javascript
// Check WASM status
console.log('WASM loaded:', !!wasmInstance);

// View available functions
console.log('Functions:', Object.keys(wasmInstance.exports));

// Check memory usage
console.log('Memory:', wasmInstance.exports.get_memory_usage(), '/', 
                     wasmInstance.exports.get_memory_capacity());

// Get last error
const errorLen = wasmInstance.exports.get_last_error_len();
if (errorLen > 0) {
    const errorPtr = wasmInstance.exports.get_last_error();
    const errorArray = new Uint8Array(wasmMemory.buffer, errorPtr, errorLen);
    console.log('Last error:', new TextDecoder().decode(errorArray));
}
```

## 📈 Roadmap

### Planned Features
- [ ] Audio track support
- [ ] Video import/export
- [ ] Advanced effects (blur, sharpen)
- [ ] Multi-track timeline
- [ ] Keyframe animation
- [ ] WebGL acceleration
- [ ] Mobile touch controls

### Performance Goals
- [ ] 4K video support
- [ ] Real-time effects preview
- [ ] Hardware decoding integration
- [ ] Multi-threading with Web Workers

## 🤝 Contributing

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature-name`
3. **Test thoroughly**: Ensure all tests pass
4. **Submit pull request**: Include description and test results

### Code Style
- **Zig**: Follow standard Zig formatting
- **JavaScript**: Use modern ES6+ features
- **Comments**: Document public functions
- **Error Handling**: Always check return values

## 📄 License

This project is licensed under the MIT License. See LICENSE file for details.

## 🙏 Acknowledgments

- **Zig Language Team**: For excellent WebAssembly support
- **WebRTC Community**: For browser media standards
- **WebAssembly Working Group**: For making this possible

---

**Built with ❤️ using Zig and WebAssembly**

For questions, issues, or contributions, please open an issue or pull request.