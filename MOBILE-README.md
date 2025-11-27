# 📱 Mobile Video Recorder

A reliable mobile video recording app that won't crash like TikTok's camera! Built as a Progressive Web App (PWA) with WebAssembly for high performance.

## ✨ Features

- **Crash-resistant recording** - Engineered for stability
- **High-quality video export** - MP4/WebM with customizable settings
- **Mobile-first design** - Touch-optimized interface
- **Offline capable** - Works without internet connection
- **Background recording** - Continues recording when app is backgrounded
- **Pinch-to-zoom** - Gesture controls for camera zoom
- **Flash support** - Toggle flashlight during recording
- **Grid overlay** - Rule of thirds for better composition
- **Multiple camera support** - Switch between front/back cameras
- **PWA installable** - Add to home screen like a native app

## 🚀 Quick Start

### Option 1: Install as PWA (Recommended)
1. Visit the app URL in your mobile browser
2. Tap "Add to Home Screen" or "Install App"
3. Launch from your home screen like any other app

### Option 2: Build from Source
```bash
# Clone the repository
git clone https://github.com/yourusername/video-editor.git
cd video-editor

# Build the mobile app
./build-mobile.sh

# Start local HTTPS server (required for camera access)
cd zig/zig-out/web
./serve.sh
```

### Option 3: F-Droid Compatible
The app is built as a PWA which makes it compatible with F-Droid's web app support:
1. Build the app using the instructions above
2. Host on any web server with HTTPS
3. Users can install via F-Droid's "Add Repository" feature

## 📋 Requirements

- **Mobile Browser**: Chrome 88+, Firefox 85+, Safari 14+
- **Camera Permission**: Required for video recording
- **Microphone Permission**: Required for audio recording
- **HTTPS**: Required in production for camera access
- **Storage**: ~5MB for app, additional space for videos

## 🔧 Building

### Prerequisites
- [Zig 0.11+](https://ziglang.org/)
- Modern web browser
- HTTPS server for testing (included in build)

### Build Commands
```bash
# Build everything (mobile-optimized)
./build-mobile.sh

# Build WASM module only
cd zig && zig build mobile

# Test locally with HTTPS
cd zig/zig-out/web && ./serve.sh
```

## 📱 Usage

### Recording Video
1. **Grant Permissions**: Allow camera and microphone access
2. **Adjust Settings**: Tap ⚙️ to change quality, framerate, format
3. **Start Recording**: Tap the red record button
4. **Stop Recording**: Tap the stop button (red square)
5. **Export Video**: Tap 💾 to save to device

### Camera Controls
- **Switch Camera**: Tap 🔄 to toggle front/back camera
- **Zoom**: Pinch gesture or tap 1×/2×/5× buttons
- **Flash**: Tap ⚡ to toggle flashlight
- **Grid**: Tap ⊞ to show composition grid

### Video Settings
- **Quality**: 4K, 1080p, 720p, 480p
- **Frame Rate**: 60fps, 30fps, 24fps
- **Format**: MP4 (H.264) or WebM (VP9)

## 🛠️ Development

### Project Structure
```
video-editor/
├── zig/src/
│   ├── main.zig              # WASM module core
│   └── web/
│       ├── mobile.html       # Mobile app UI
│       ├── mobile-app.js     # App logic
│       ├── manifest.json     # PWA manifest
│       └── sw.js            # Service worker
├── build-mobile.sh          # Build script
└── MOBILE-README.md         # This file
```

### Key Components
- **WASM Core**: High-performance video processing in Zig
- **Mobile UI**: Touch-optimized interface with gesture support
- **Service Worker**: Offline support and background sync
- **PWA Manifest**: Native app installation support

### Testing
```bash
# Build and test locally
./build-mobile.sh
cd zig/zig-out/web
./serve.sh

# Open https://localhost:8443 in mobile browser
# Accept self-signed certificate
# Test camera functionality
```

## 🚀 Deployment

### Static Hosting
The app is a static PWA that can be hosted on any web server:

```bash
# Example: Deploy to your web server
rsync -avz zig/zig-out/web/ user@server:/var/www/video-recorder/

# Example: GitHub Pages
git subtree push --prefix zig/zig-out/web origin gh-pages
```

### Server Configuration
Ensure your server:
- Serves over HTTPS (required for camera access)
- Sets correct MIME types (especially `.wasm` → `application/wasm`)
- Enables compression for better performance
- Sets appropriate cache headers

Example nginx config is included in `nginx.conf`.

## 🔒 Privacy & Security

- **Local Processing**: All video processing happens on your device
- **No Tracking**: No analytics or user tracking
- **Secure by Default**: HTTPS required, proper security headers
- **Offline Capable**: Works without internet connection
- **Local Storage**: Videos saved directly to your device

## ⚡ Performance Tips

### For Best Recording Quality
- Use rear camera when possible (usually higher quality)
- Ensure good lighting
- Keep device steady
- Close other apps to free memory
- Ensure sufficient storage space

### Battery Optimization
- Lower frame rate (24fps) for longer recording
- Reduce resolution if battery is low
- App uses wake lock to prevent screen timeout
- Disable unnecessary features when not needed

## 🐛 Troubleshooting

### Camera Access Issues
1. **Check HTTPS**: Camera requires secure connection
2. **Grant Permissions**: Allow camera/microphone in browser
3. **Close Other Apps**: Other camera apps may block access
4. **Restart Browser**: Clear any stuck camera processes

### Recording Problems
1. **Check Storage**: Ensure sufficient space available
2. **Try Different Format**: Switch MP4 ↔ WebM
3. **Lower Quality**: Reduce resolution/framerate
4. **Restart App**: Refresh page if stuck

### Export Issues
1. **Wait for Processing**: Large videos take time
2. **Check Downloads**: Video saved to Downloads folder
3. **Try Different Browser**: Some have better download support
4. **Free Storage**: Ensure space for exported file

## 📊 Technical Specs

### Supported Formats
- **Video**: MP4 (H.264), WebM (VP9)
- **Audio**: AAC, Opus
- **Quality**: Up to 4K@60fps (device dependent)
- **File Size**: Optimized bitrates for mobile

### Browser Compatibility
- ✅ Chrome/Chromium 88+
- ✅ Firefox 85+
- ✅ Safari 14+ (iOS/macOS)
- ✅ Edge 88+
- ⚠️ Older browsers may have limited features

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Test on multiple devices
4. Commit changes: `git commit -m 'Add amazing feature'`
5. Push to branch: `git push origin feature/amazing-feature`
6. Open Pull Request

### Development Setup
```bash
git clone https://github.com/yourusername/video-editor.git
cd video-editor
./build-mobile.sh
cd zig/zig-out/web && ./serve.sh
```

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Zig](https://ziglang.org/) and WebAssembly
- Mobile UI inspired by modern camera apps
- PWA capabilities for native-like experience

---

**Mobile Video Recorder** - *Reliable video recording that actually works* 📱✨

For issues or feature requests, please open an issue on GitHub.