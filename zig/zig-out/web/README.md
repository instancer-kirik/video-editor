# Mobile Video Recorder Deployment

## Quick Test
1. Run the test server: `python3 serve.py`
2. Open https://localhost:8443/mobile.html in your mobile browser
3. Accept the self-signed certificate
4. Grant camera and microphone permissions
5. Test recording functionality

## Production Deployment
1. Upload all files to your HTTPS web server
2. Ensure proper MIME types are set:
   - `.wasm` → `application/wasm`
   - `.json` → `application/manifest+json`
3. Enable compression for better performance
4. Set appropriate cache headers

## Files Structure
- `mobile.html` - Main mobile app interface
- `mobile-app.js` - App logic and camera handling
- `video-editor.wasm` - WebAssembly video processing module
- `manifest.json` - PWA manifest for app installation
- `sw.js` - Service worker for offline functionality
- `serve.py` - Local HTTPS test server

## Browser Requirements
- HTTPS (required for camera access)
- Modern browser with WebAssembly support
- Camera and microphone permissions

Happy recording! 🎬
