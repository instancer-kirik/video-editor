# Video Editor Architecture

## Component Hierarchy

```
main.zig
├── VideoApp (Main application controller)
│   ├── UI (ui.zig)
│   │   ├── Navigation
│   │   │   ├── Record View
│   │   │   ├── Edit View
│   │   │   └── Preview View
│   │   ├── Preview
│   │   │   ├── Video Element
│   │   │   └── Canvas
│   │   └── RecordingControls
│   ├── Recorder (recorder.zig)
│   │   ├── MediaStream
│   │   ├── MediaRecorder
│   │   └── PreviewHandle
│   └── Editor (editor.zig)
│       ├── Timeline
│       ├── Layers
│       ├── Filters
│       └── TextOverlays
```

## Views

### Navigation
- Tab/button-based navigation system
- Switches between main application views:
  1. Record: Camera preview and recording controls
  2. Edit: Timeline and editing tools
  3. Preview: Final video playback

### View States
- Each view has its own state and UI components
- Smooth transitions between views
- Persistent data across view changes

## Core Components

### main.zig
- Entry point for the application
- Manages application state (Recording, Editing, Preview)
- Coordinates between UI, Recorder, and Editor components
- Handles global events and state transitions

### web.zig
- Core WebAssembly bindings and interfaces
- Provides low-level access to browser APIs:
  - Media devices (camera/microphone)
  - DOM manipulation
  - Canvas operations
  - Media recording
  - File handling
- Defines opaque types for JavaScript interop:
  - Element
  - MediaStreamHandle
  - MediaRecorderHandle
  - PreviewHandle
  - Layer

### ui.zig
- Main UI container and layout management
- Event queue for UI interactions
- Components:
  - Preview: Video/canvas display
  - Controls: Recording and editing controls
  - Layout management and styling

### recorder.zig
- Handles video/audio recording functionality
- Manages MediaStream and MediaRecorder
- Features:
  - Start/stop recording
  - Stream management
  - Preview rendering
  - Chunk collection
  - Error handling

### editor.zig
- Video editing capabilities
- Features:
  - Multi-layer composition
  - Video/audio tracks
  - Text overlays
  - Filters and effects
  - Timeline management
  - Undo/redo support

### preview.zig
- Video preview component
- Manages:
  - Video element for camera feed
  - Canvas for effects/overlays
  - Stream display
  - Layout and styling

## Data Flow

1. User Interaction
   ```
   UI Event -> UI.event_queue -> VideoApp -> Specific Component
   ```

2. Recording Flow
   ```
   Start Recording:
   UI.controls -> VideoApp -> Recorder -> MediaRecorder -> Chunks

   Preview:
   MediaStream -> Preview -> Canvas/Video Element
   ```

3. Editing Flow
   ```
   Editor Action -> Timeline Update -> Layer Management -> Preview Render
   ```

## State Management

### AppState (in main.zig)
- Preview: Initial state, showing camera feed
- Recording: Active recording state
- Editing: Post-recording editing state

### Recording State (in recorder.zig)
- Inactive: No recording
- Recording: Active recording
- Paused: Paused recording

### Editor State (in editor.zig)
- Timeline position
- Selected layer
- Active tools
- Undo/redo history

## Module Dependencies

```
main.zig
├── components/
│   ├── mod.zig (module aggregator)
│   ├── ui.zig
│   │   ├── preview.zig
│   │   └── controls.zig
│   ├── recorder.zig
│   ├── editor.zig
│   ├── media.zig
│   └── types.zig
└── web.zig (WASM bindings)
```

## Future Considerations

1. Mobile Support
   - Touch interactions
   - Responsive layout
   - Performance optimizations

2. Advanced Features
   - More filters and effects
   - Advanced timeline operations
   - Export options
   - Subtitle support
   - Multi-language support

3. Performance Improvements
   - WebGL rendering
   - Worker-based processing
   - Efficient memory management 