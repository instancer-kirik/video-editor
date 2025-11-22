# Video Editor 🎬

A modern browser-based video recorder and editor inspired by TikTok, built with Godot and Zig for high performance and smooth user experience.

## Features

- **Real-time Recording**: Browser-based video recording with live preview
- **Multi-layer Editing**: Advanced timeline with video, audio, and text layers
- **Effects & Filters**: Real-time video effects and filters
- **Text Overlays**: Dynamic text with customizable styling
- **WebAssembly Performance**: High-performance core built with Zig
- **Responsive UI**: Works on desktop and mobile browsers
- **No Installation**: Runs entirely in the browser

## Architecture

Video Editor combines the power of Godot's UI framework with Zig's WebAssembly performance:

- **Frontend**: Godot 4.3 for UI and scene management
- **Core Engine**: Zig compiled to WebAssembly for video processing
- **Browser APIs**: Native integration with MediaRecorder and Canvas APIs

## Project Structure

```
├── scenes/           # Godot scene files
├── scripts/          # GDScript files
├── zig/             # Zig source code and WebAssembly build
│   ├── src/         # Zig source files
│   └── build.zig    # Zig build configuration
├── resources/       # Assets and resources
├── shaders/         # Custom shaders
└── examples/        # Usage examples
```

## Getting Started

### Prerequisites

- Godot 4.3 or later
- Zig 0.11 or later
- Modern web browser with WebAssembly support

### Development Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/video-editor.git
   cd video-editor
   ```

2. **Build the Zig WebAssembly module**:
   ```bash
   cd zig
   zig build
   ```

3. **Open in Godot**:
   - Launch Godot
   - Import the project by selecting `project.godot`
   - Run the project (F5)

### Building for Web

```bash
# Build WebAssembly module
cd zig
zig build

# Export from Godot
# File -> Export -> Web -> Export Project
```

## Usage

### Recording
1. Click "Record" to start camera/screen capture
2. Use real-time filters and effects while recording
3. Stop recording when finished

### Editing
1. Switch to "Edit" view
2. Use the timeline to trim and arrange clips
3. Add text overlays, effects, and transitions
4. Preview your edits in real-time

### Export
1. Go to "Preview" view
2. Review your final video
3. Export in various formats and qualities

## Development

### Key Components

- **VideoApp** (`zig/src/main.zig`): Main application controller
- **UI** (`scripts/`): Godot-based user interface
- **Recorder** (`zig/src/recorder.zig`): Video recording functionality
- **Editor** (`zig/src/editor.zig`): Video editing engine
- **Web Bindings** (`zig/src/web.zig`): Browser API integration

### State Management

The application manages three main states:
- **Preview**: Camera feed with recording controls
- **Recording**: Active recording state
- **Editing**: Post-recording editing interface

## Browser Support

- Chrome 88+ (recommended)
- Firefox 85+
- Safari 14+
- Edge 88+

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Roadmap

- [ ] Advanced timeline operations
- [ ] More video effects and filters
- [ ] Audio editing capabilities
- [ ] Subtitle support
- [ ] Mobile app export
- [ ] Cloud storage integration
- [ ] Collaborative editing

## Performance

Video Editor is designed for performance:
- WebAssembly core for intensive video processing
- Efficient memory management
- Hardware-accelerated rendering where available
- Optimized for 60fps real-time editing

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [Godot Engine](https://godotengine.org/)
- Core engine written in [Zig](https://ziglang.org/)
- Inspired by modern video editing workflows

---

**Video Editor** - *Smooth video editing in your browser* 🎬✨