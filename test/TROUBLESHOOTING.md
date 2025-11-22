# 🔧 Video Editor Troubleshooting Guide

## Common Issues & Solutions

### 🎥 Camera Issues

#### "Cannot read properties of undefined (reading 'getUserMedia')"
**Cause**: Camera access requires HTTPS or localhost  
**Solution**:
- Use `https://` instead of `http://`
- Or serve from `localhost` (not `127.0.0.1` or your IP)
- Or use `python3 -m http.server 8080` from localhost

#### "Camera permission denied"
**Cause**: Browser blocked camera access  
**Solution**:
1. Click the camera icon in address bar
2. Select "Always allow" for camera access
3. Refresh the page

#### "No camera found"
**Cause**: No camera device connected  
**Solution**:
- Connect a webcam or use built-in camera
- Check if camera is being used by another app
- Restart browser if camera was just connected

### 🚀 Loading Issues

#### "WASM Failed to load"
**Cause**: WebAssembly file not found or corrupted  
**Solution**:
```bash
# Rebuild WASM binary
cd video-editor/zig
zig build wasm
cp zig-out/bin/video-editor.wasm ../test/
```

#### "Server Address already in use"
**Cause**: Port 8080 is occupied  
**Solution**:
```bash
# Kill existing servers
pkill -f "python.*http.server"
# Or use different port
python3 -m http.server 8081
```

#### "ERR_EMPTY_RESPONSE"
**Cause**: Server not properly started  
**Solution**:
1. Stop all existing servers
2. Wait 5 seconds
3. Start server again with proper directory:
```bash
cd video-editor/test
python3 -m http.server 8080
```

### ⏰ Timeline Issues

#### "No way to access timeline"
**Cause**: Using old interface instead of workspace  
**Solution**:
- Navigate to `/workspace.html` (not `/index.html`)
- Or click "Professional Workspace" button
- Full URL: `http://localhost:8080/workspace.html`

#### "Clips don't appear on timeline"
**Cause**: Not using auto-add workflow  
**Solution**:
1. Record video → Automatically adds to timeline
2. Import files → Double-click clips → Adds to timeline
3. Drag from Media Library to timeline tracks

#### "Can't select or move clips"
**Cause**: JavaScript errors or improper loading  
**Solution**:
1. Open browser dev tools (F12)
2. Check Console for errors
3. Refresh page if WASM didn't load properly

### 🎨 Effects Issues

#### "Filters don't work"
**Cause**: WASM functions not properly loaded  
**Solution**:
1. Check WASM status in top toolbar
2. Should show "✅ WASM Ready"
3. If not, refresh page and check console errors

#### "No thumbnails in media library"
**Cause**: Video file format not supported  
**Solution**:
- Use common formats: .mp4, .webm
- Check browser console for errors
- Try smaller video files first

### 🌐 Browser Compatibility

#### Chrome (Recommended)
- ✅ Full support for all features
- Best performance and compatibility

#### Firefox
- ✅ Good support
- Some WebRTC limitations on older versions

#### Safari
- ⚠️ Limited WebRTC support
- Camera recording may not work properly
- Use Chrome or Firefox instead

#### Mobile Browsers
- ⚠️ Limited features
- Touch interface needs improvement
- Desktop browser recommended

### 🛠️ Development Issues

#### "Permission denied" on launch script
**Solution**:
```bash
chmod +x launch_workspace.sh
```

#### "Python not found"
**Solution**:
```bash
# Ubuntu/Debian
sudo apt install python3

# macOS
brew install python3

# Or use Node.js
npm install -g http-server
http-server -p 8080
```

#### "CORS errors"
**Solution**:
- Don't open files directly in browser (file://)
- Always use HTTP server
- Check proper MIME types for .wasm files

## 🔍 Debugging Steps

### 1. Check Browser Console
1. Press F12 to open dev tools
2. Go to Console tab
3. Look for red error messages
4. Common errors and solutions listed above

### 2. Verify Files
```bash
cd video-editor/test
ls -la
# Should see:
# - workspace.html (59KB+)
# - video-editor.wasm (689KB+)
# - index.html (redirect page)
```

### 3. Test Server
```bash
curl http://localhost:8080/workspace.html
# Should return HTML content, not 404
```

### 4. Check Network Tab
1. F12 → Network tab
2. Refresh page
3. Look for failed requests (red entries)
4. Verify video-editor.wasm loads successfully

## 🎯 Working Configuration

**Recommended Setup**:
- **Server**: Python 3 HTTP server
- **Browser**: Chrome or Firefox
- **URL**: `http://localhost:8080/workspace.html`
- **Protocol**: HTTP is OK for localhost, HTTPS needed for remote

**File Structure**:
```
video-editor/test/
├── workspace.html          ← Main interface
├── video-editor.wasm       ← 689KB binary
├── index.html             ← Redirect page
└── launch_workspace.sh    ← Auto launcher
```

## 🆘 Still Having Issues?

1. **Clear browser cache** (Ctrl+Shift+R)
2. **Try different browser** (Chrome recommended)
3. **Check browser version** (needs modern WebAssembly support)
4. **Try localhost instead of IP address**
5. **Disable browser extensions** temporarily
6. **Check antivirus/firewall** isn't blocking localhost

## 📞 Quick Solutions

**Can't see workspace**: Go to `/workspace.html` not `/index.html`  
**Camera not working**: Use `https://` or `localhost`  
**WASM errors**: Rebuild with `zig build wasm`  
**Server errors**: Use different port `python3 -m http.server 8081`  
**No thumbnails**: Use .mp4 files, check console errors  

## ✅ Success Indicators

- ✅ "WASM Ready" in top toolbar
- ✅ Camera preview appears when recording
- ✅ Clips auto-add to timeline after recording
- ✅ Timeline clips are clickable and draggable
- ✅ Properties panel updates when selecting clips
- ✅ Video thumbnails appear in media library

When everything works, you should see a professional video editor interface with working camera, timeline, and real-time effects!