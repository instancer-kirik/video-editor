# WebSocket Debug Checklist

## Import Issues
- [x] Check if Phoenix dependencies are properly installed in `package.json`
- [x] Verify import paths for Phoenix modules
- [x] Ensure webpack is configured to handle Phoenix imports
- [ ] Check for any lockdown/security policies blocking imports

## LiveSocket Setup
- [x] Verify CSRF token is properly set in meta tag
- [x] Check LiveSocket initialization parameters
- [x] Ensure hooks are properly defined
- [x] Verify Socket endpoint path

## WASM Integration
- [x] Verify WASM files are properly built and copied
- [x] Add Zig output directory to webpack modules path
- [x] Exclude Zig files from babel processing
- [ ] Ensure WASM files are served with correct MIME type
- [ ] Monitor WASM initialization in browser console

## Connection Flow
- [ ] Check if socket connects successfully
- [ ] Monitor socket lifecycle events
- [ ] Verify LiveView mount callback
- [ ] Check for any connection errors

## Required Fixes

1. Fix Phoenix imports in app.js:
```javascript
// Correct imports
import { Socket } from "phoenix";
import "phoenix_html";
import { LiveSocket } from "phoenix_live_view/phoenix_live_view.js";  // Note the full path
```

2. Update package.json dependencies:
```json
{
  "dependencies": {
    "core-js": "^3.35.1",
    "phoenix": "file:../deps/phoenix",
    "phoenix_html": "file:../deps/phoenix_html",
    "phoenix_live_view": "file:../deps/phoenix_live_view"
  }
}
```

3. Update webpack config:
```javascript
module.exports = {
  // ... other config ...
  resolve: {
    extensions: ['.js', '.wasm'],
    modules: [
      'node_modules',
      '../deps',
      path.resolve(__dirname, '../../../../zig/zig-out/web')
    ],
    alias: {
      phoenix: path.resolve(__dirname, '../deps/phoenix/priv/static/phoenix.js'),
      'phoenix_html': path.resolve(__dirname, '../deps/phoenix_html/priv/static/phoenix_html.js'),
      'phoenix_live_view': path.resolve(__dirname, '../deps/phoenix_live_view/priv/static'),  // Point to directory
      'video_editor.js': path.resolve(__dirname, '../../../../zig/zig-out/web/video_editor.js')
    }
  }
}
```

4. Update video_editor.js import:
```javascript
import init from 'video_editor.js';  // Direct import using webpack alias
```

## Common Issued
1. Missing or incorrect Phoenix package versions
2. Import path resolution problems
3. CSRF token not properly set
4. WebSocket endpoint configuration issues
5. Security policies blocking WebSocket connections
6. WASM file MIME type issues
7. Lockdown/security policy blocking WASM
8. Zig files being processed by babel
9. Phoenix LiveView module path resolution

## Next Steps
1. Run `npm install` to ensure all dependencies are installed
2. Check browser console for detailed error messages
3. Verify Phoenix endpoint configuration
4. Test WebSocket connection using browser dev tools
5. Monitor network tab for WebSocket handshake
6. Check WASM file loading in network tab
7. Monitor WASM initialization in console 