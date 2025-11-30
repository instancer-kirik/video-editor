import { webBindings } from './bindings.js';

let wasm;

// Helper functions for WASM memory handling
function getString(ptr) {
    if (!ptr) return null;
    const memory = new Uint8Array(wasm.memory.buffer);
    let str = '';
    let i = ptr;
    while (memory[i] !== 0) {
        str += String.fromCharCode(memory[i]);
        i++;
    }
    return str;
}

function getObject(ptr) {
    if (!ptr) return null;
    return objectRegistry.get(ptr) || null;
}

// Object registry for handling JS objects in WASM
const objectRegistry = new Map();
let nextObjectId = 1;

function registerObject(obj) {
    const id = nextObjectId++;
    objectRegistry.set(id, obj);
    return id;
}

function unregisterObject(id) {
    objectRegistry.delete(id);
}

// WASI imports required for wasm32-wasi target
const wasi = {
    // Minimal WASI implementation
    proc_exit: (code) => {
        console.log(`WASI proc_exit called with code ${code}`);
    },
    random_get: (ptr, len) => {
        const buffer = new Uint8Array(wasm.memory.buffer, ptr, len);
        crypto.getRandomValues(buffer);
        return 0;
    },
    fd_write: (fd, iovs_ptr, iovs_len, nwritten_ptr) => {
        console.log('WASI fd_write called:', { fd, iovs_ptr, iovs_len, nwritten_ptr });
        return 0;
    },
    fd_close: (fd) => {
        console.log('WASI fd_close called:', fd);
        return 0;
    },
    fd_seek: (fd, offset, whence, newOffset) => {
        console.log('WASI fd_seek called:', { fd, offset, whence, newOffset }); 
        return 0;
    },
    environ_sizes_get: (environ_count_out, environ_buf_size_out) => {
        console.log('WASI environ_sizes_get called');
        return 0;
    },
    environ_get: (environ_ptr, environ_buf_ptr) => {
        console.log('WASI environ_get called');
        return 0;
    },
    clock_time_get: (id, precision, out_ptr) => {
        const view = new DataView(wasm.memory.buffer);
        // Convert milliseconds to nanoseconds without using BigInt literals
        const timeMs = Date.now();
        const timeNs = BigInt(timeMs) * BigInt(1000000);
        view.setBigUint64(out_ptr, timeNs, true);
        return 0;
    },
};

// Environment bindings for Zig functionality
const envBindings = {
    memory: new WebAssembly.Memory({ initial: 256 }),
    
    // Required by WASM module
    start: () => {
        console.log('WASM start function called');
        return 0;
    },
    
    // Media recorder functions
    createMediaRecorderInternal: (stream_handle) => {
        console.log('Creating media recorder for stream:', stream_handle);
        return new MediaRecorder(stream_handle, {
            mimeType: 'video/webm',
            videoBitsPerSecond: 2500000,
            audioBitsPerSecond: 128000
        });
    },

    setDataAvailableCallback: (callback_ptr) => {
        console.log('Setting data available callback:', callback_ptr);
        const callback = getObject(callback_ptr);
        if (typeof callback === 'function') {
            return __retain(callback);
        }
        return 0;
    },

    setErrorCallback: (callback_ptr) => {
        console.log('Setting error callback:', callback_ptr);
        const callback = getObject(callback_ptr);
        if (typeof callback === 'function') {
            return __retain(callback);
        }
        return 0;
    },

    setOnClick: (element_ptr, context_ptr, callback_ptr) => {
        console.log('Setting onClick handler:', { element_ptr, context_ptr, callback_ptr });
        const element = getObject(element_ptr);
        const callback = getObject(callback_ptr);
        if (element && typeof callback === 'function') {
            element.addEventListener('click', () => {
                callback(context_ptr);
            });
            return __retain(callback);
        }
        return 0;
    },

    createPreviewHandleInternal: () => {
        console.log('Creating preview handle');
        return {
            canvas: null,
            videoSource: null,
            isActive: false,
            animationFrame: null
        };
    },

    // Media stream functions
    getUserMedia: async (constraints_ptr) => {
        console.log('Getting user media with constraints:', constraints_ptr);
        try {
            // Default constraints if none provided
            const defaultConstraints = {
                video: {
                    width: { ideal: 1280 },
                    height: { ideal: 720 },
                    frameRate: { ideal: 30 }
                },
                audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true
                }
            };

            console.log('Requesting media with constraints:', defaultConstraints);
            const stream = await navigator.mediaDevices.getUserMedia(defaultConstraints);
            console.log('Got media stream:', stream, 'Active:', stream.active, 'Tracks:', stream.getTracks());
            
            // Set up video preview
            const video = document.getElementById('preview-video');
            console.log('Video element:', video);
            
            if (video) {
                console.log('Setting up video preview');
                video.style.display = 'block';
                video.style.width = '100%';
                video.style.height = '100%';
                video.style.objectFit = 'contain';
                video.style.background = '#000';
                video.style.position = 'absolute';
                video.style.top = '0';
                video.style.left = '0';
                video.style.zIndex = '1';
                
                video.srcObject = stream;
                video.muted = true;
                video.playsInline = true;
                video.autoplay = true;
                
                try {
                    await video.play();
                    console.log('Video preview started successfully');
                } catch (err) {
                    console.error('Error playing video:', err);
                }
            } else {
                console.error('No video element found with id "preview-video"');
            }

            // Create a wrapper object that includes the getStream method
            const streamWrapper = {
                stream,
                getStream: () => stream
            };

            return __retain(streamWrapper);
        } catch (error) {
            console.error('Failed to get user media:', error);
            return 0;
        }
    },

    getVideoTrack: (stream_handle) => {
        const obj = getObject(stream_handle);
        const stream = obj?.stream || obj;
        if (!stream) return null;
        const tracks = stream.getVideoTracks();
        console.log('Video tracks:', tracks);
        return tracks[0] || null;
    },

    getAudioTrack: (stream_handle) => {
        const obj = getObject(stream_handle);
        const stream = obj?.stream || obj;
        if (!stream) return null;
        const tracks = stream.getAudioTracks();
        console.log('Audio tracks:', tracks);
        return tracks[0] || null;
    },

    // DOM manipulation
    setStyle: (element_ptr, property_ptr, value_ptr) => {
        const element = getObject(element_ptr);
        const property = getString(property_ptr);
        const value = getString(value_ptr);
        if (element && property && value) {
            element.style[property] = value;
        }
    },
    setAttribute: (element_ptr, attr_ptr, value_ptr) => {
        const element = getObject(element_ptr);
        const attr = getString(attr_ptr);
        const value = getString(value_ptr);
        if (element && attr && value) {
            element.setAttribute(attr, value);
        }
    },
    setText: (element_ptr, text_ptr) => {
        const element = getObject(element_ptr);
        const text = getString(text_ptr);
        if (element && text) {
            element.textContent = text;
        }
    },
    addClass: (element_ptr, class_ptr) => {
        console.log('addClass called:', { element_ptr, class_ptr });
        return 0;
    },
    removeClass: (element_ptr, class_ptr) => {
        console.log('removeClass called:', { element_ptr, class_ptr });
        return 0;
    },
    appendChild: (parent_ptr, child_ptr) => {
        console.log('appendChild called:', { parent_ptr, child_ptr });
        return 0;
    },
    removeChild: (parent_ptr, child_ptr) => {
        console.log('removeChild called:', { parent_ptr, child_ptr });
        return 0;
    },
    enable: (element_ptr) => {
        console.log('enable called:', { element_ptr });
        return 0;
    },
    disable: (element_ptr) => {
        console.log('disable called:', { element_ptr });
        return 0;
    },
    clear: () => {
        console.log('clear called');
        return 0;
    },
    
    // Camera and Media functions
    initCameraJS: (constraints_ptr) => {
        console.log('initCameraJS called with constraints:', constraints_ptr);
        return 0;
    },
    startRecording: () => {
        console.log('startRecording called');
        return 0;
    },
    stopRecording: () => {
        console.log('stopRecording called');
        return 0;
    },
    stop: () => {
        console.log('stop called');
        return 0;
    },
    
    // Layer Management
    createLayer: (type_ptr, name_ptr) => {
        console.log('createLayer called:', { type_ptr, name_ptr });
        return 0;
    },
    deleteLayer: (layer_id) => {
        console.log('deleteLayer called:', { layer_id });
        return 0;
    },
    setLayerVisibility: (layer_id, visible) => {
        console.log('setLayerVisibility called:', { layer_id, visible });
        return 0;
    },
    setLayerLock: (layer_id, locked) => {
        console.log('setLayerLock called:', { layer_id, locked });
        return 0;
    },
    setLayerPosition: (layer_id, x, y) => {
        console.log('setLayerPosition called:', { layer_id, x, y });
        return 0;
    },
    setLayerScale: (layer_id, x, y) => {
        console.log('setLayerScale called:', { layer_id, x, y });
        return 0;
    },
    setLayerRotation: (layer_id, angle) => {
        console.log('setLayerRotation called:', { layer_id, angle });
        return 0;
    },
    setLayerOpacity: (layer_id, opacity) => {
        console.log('setLayerOpacity called:', { layer_id, opacity });
        return 0;
    },
    setLayerBlendMode: (layer_id, mode_ptr) => {
        console.log('setLayerBlendMode called:', { layer_id, mode_ptr });
        return 0;
    },
    
    // Video Processing
    addVideoLayer: (data_ptr, size) => {
        console.log('addVideoLayer called:', { data_ptr, size });
        return 0;
    },
    processFrame: (frame_ptr, width, height) => {
        console.log('processFrame called:', { frame_ptr, width, height });
        return 0;
    },
    applyEffect: (layer_id, effect_ptr, params_ptr) => {
        console.log('applyEffect called:', { layer_id, effect_ptr, params_ptr });
        return 0;
    },
    
    // Motion Tracking
    addTrackPoint: (x, y) => {
        console.log('addTrackPoint called:', { x, y });
        return 0;
    },
    updateTrackPoint: (id, x, y) => {
        console.log('updateTrackPoint called:', { id, x, y });
        return 0;
    },
    startTracking: (point_id) => {
        console.log('startTracking called:', { point_id });
        return 0;
    },
    stopTracking: (point_id) => {
        console.log('stopTracking called:', { point_id });
        return 0;
    },
    getTrackingData: (point_id) => {
        console.log('getTrackingData called:', { point_id });
        return 0;
    },
    
    // Masking and Compositing
    createMask: (type_ptr, points_ptr, num_points) => {
        console.log('createMask called:', { type_ptr, points_ptr, num_points });
        return 0;
    },
    updateMask: (mask_id, points_ptr, num_points) => {
        console.log('updateMask called:', { mask_id, points_ptr, num_points });
        return 0;
    },
    setMaskFeather: (mask_id, amount) => {
        console.log('setMaskFeather called:', { mask_id, amount });
        return 0;
    },
    setMaskInvert: (mask_id, invert) => {
        console.log('setMaskInvert called:', { mask_id, invert });
        return 0;
    },
    
    // Effects and Filters
    applyColorCorrection: (layer_id, params_ptr) => {
        console.log('applyColorCorrection called:', { layer_id, params_ptr });
        return 0;
    },
    applyBlur: (layer_id, radius) => {
        console.log('applyBlur called:', { layer_id, radius });
        return 0;
    },
    applySharpen: (layer_id, amount) => {
        console.log('applySharpen called:', { layer_id, amount });
        return 0;
    },
    applyNoise: (layer_id, amount, type_ptr) => {
        console.log('applyNoise called:', { layer_id, amount, type_ptr });
        return 0;
    },
    
    // Timeline and Playback
    setPlaybackPosition: (time_ms) => {
        console.log('setPlaybackPosition called:', { time_ms });
        return 0;
    },
    setPlaybackRate: (rate) => {
        console.log('setPlaybackRate called:', { rate });
        return 0;
    },
    setInPoint: (time_ms) => {
        console.log('setInPoint called:', { time_ms });
        return 0;
    },
    setOutPoint: (time_ms) => {
        console.log('setOutPoint called:', { time_ms });
        return 0;
    },
    
    // Canvas operations
    drawFrame: (frame_ptr, width, height) => {
        console.log('drawFrame called:', { frame_ptr, width, height });
        return 0;
    },
    updateCanvas: (width, height) => {
        console.log('updateCanvas called:', { width, height });
        return 0;
    },
    
    // Export and Rendering
    startRender: (params_ptr) => {
        console.log('startRender called:', { params_ptr });
        return 0;
    },
    cancelRender: () => {
        console.log('cancelRender called');
        return 0;
    },
    getRenderProgress: () => {
        console.log('getRenderProgress called');
        return 0;
    },
    
    // Project Management
    saveProject: (path_ptr) => {
        console.log('saveProject called:', { path_ptr });
        return 0;
    },
    loadProject: (path_ptr) => {
        console.log('loadProject called:', { path_ptr });
        return 0;
    },
    
    // Error Handling
    getLastError: () => {
        console.log('getLastError called');
        return 0;
    },
    clearError: () => {
        console.log('clearError called');
        return 0;
    },
    
    // Video Processing bindings
    createVideoFromBlob: (blob_ptr, blob_len) => {
        console.log('createVideoFromBlob called:', { blob_ptr, blob_len });
        return new Promise((resolve, reject) => {
            const blob = new Blob([new Uint8Array(wasm.memory.buffer, blob_ptr, blob_len)], { type: 'video/webm' });
            const video = document.createElement('video');
            video.muted = true;
            video.preload = 'auto';
            
            const url = URL.createObjectURL(blob);
            video.src = url;
            
            video.onloadedmetadata = () => {
                if (video.duration && isFinite(video.duration)) {
                    resolve({
                        video,
                        url,
                        duration: video.duration,
                        width: video.videoWidth,
                        height: video.videoHeight
                    });
                } else {
                    URL.revokeObjectURL(url);
                    reject(new Error('Invalid video duration'));
                }
            };
            
            video.onerror = () => {
                URL.revokeObjectURL(url);
                reject(new Error(`Video load error: ${video.error?.message || 'Unknown error'}`));
            };
            
            video.load();
        });
    },
    
    getVideoMetadata: (handle) => {
        const video = videoHandles.get(handle);
        if (!video) return null;
        
        return {
            duration_ms: Math.round(video.duration * 1000),
            width: video.videoWidth,
            height: video.videoHeight,
            frame_rate: 30 // TODO: Get actual frame rate
        };
    },
    
    createVideoLayer: (handle) => {
        const videoData = videoHandles.get(handle);
        if (!videoData) {
            console.error('Video handle not found:', handle);
            return null;
        }
        
        const layer = {
            id: Date.now(),
            type: 'video',
            video: videoData.video,
            url: videoData.url,
            visible: true,
            locked: false,
            position: { x: 0, y: 0 },
            scale: { x: 1, y: 1 },
            rotation: 0,
            startTime: 0,
            duration: Math.round(videoData.duration * 1000)
        };
        
        console.log('Creating video layer:', layer);
        layerHandles.set(layer.id, layer);

        // Create and add layer to timeline
        const timelineLayers = document.querySelector('.timeline-layers');
        if (timelineLayers) {
            const layerTrack = document.createElement('div');
            layerTrack.className = 'timeline-layer';
            layerTrack.dataset.layerId = layer.id;
            
            // Add styles to the layer track
            layerTrack.style.cssText = `
                background: #3d3d3d;
                border-radius: 4px;
                padding: 4px 8px;
                margin: 2px 0;
                display: flex;
                justify-content: space-between;
                align-items: center;
                height: 30px;
                cursor: pointer;
                user-select: none;
                transition: background-color 0.2s;
            `;
            
            layerTrack.innerHTML = `
                <div class="layer-label" style="font-size: 12px;">Video Layer (${Math.round(layer.duration / 1000)}s)</div>
                <div class="layer-controls" style="display: flex; gap: 4px;">
                    <button class="layer-visibility" title="Toggle visibility" style="background: none; border: none; color: white; cursor: pointer; padding: 2px;">👁️</button>
                    <button class="layer-lock" title="Toggle lock" style="background: none; border: none; color: white; cursor: pointer; padding: 2px;">🔓</button>
                </div>
            `;
            
            // Add event listeners for layer controls
            const visibilityBtn = layerTrack.querySelector('.layer-visibility');
            const lockBtn = layerTrack.querySelector('.layer-lock');
            
            visibilityBtn?.addEventListener('click', (e) => {
                e.stopPropagation();
                layer.visible = !layer.visible;
                visibilityBtn.textContent = layer.visible ? '👁️' : '👁️‍🗨️';
                layerTrack.classList.toggle('hidden', !layer.visible);
                // Trigger redraw
                const event = new CustomEvent('layerVisibilityChanged', { detail: { layerId: layer.id, visible: layer.visible } });
                document.dispatchEvent(event);
            });
            
            lockBtn?.addEventListener('click', (e) => {
                e.stopPropagation();
                layer.locked = !layer.locked;
                lockBtn.textContent = layer.locked ? '🔒' : '🔓';
                layerTrack.classList.toggle('locked', layer.locked);
            });
            
            // Add hover effect
            layerTrack.addEventListener('mouseenter', () => {
                layerTrack.style.backgroundColor = '#4d4d4d';
            });
            
            layerTrack.addEventListener('mouseleave', () => {
                layerTrack.style.backgroundColor = '#3d3d3d';
            });
            
            timelineLayers.appendChild(layerTrack);
        }

        // Show timeline if hidden
        const timeline = document.querySelector('.timeline');
        if (timeline) {
            timeline.style.display = 'block';
        }

        return layer.id;
    },
    
    drawLayers: (ctx, currentTime) => {
        for (const layer of layerHandles.values()) {
            if (!layer.visible) continue;
            
            ctx.save();
            ctx.translate(layer.position.x, layer.position.y);
            ctx.rotate(layer.rotation * Math.PI / 180);
            ctx.scale(layer.scale.x, layer.scale.y);
            
            if (layer.type === 'video' && layer.video) {
                const videoTime = (currentTime - layer.startTime) / 1000;
                if (videoTime >= 0 && videoTime <= layer.duration / 1000) {
                    // Use modulo to loop the video if needed
                    layer.video.currentTime = videoTime % layer.video.duration;
                    ctx.drawImage(layer.video, 0, 0, ctx.canvas.width, ctx.canvas.height);
                }
            }
            
            ctx.restore();
        }
    },

    getLayers: () => {
        return Array.from(layerHandles.values()).map(layer => ({
            id: layer.id,
            type: layer.type,
            name: layer.type === 'video' ? `Video Layer (${Math.round(layer.duration / 1000)}s)` : 'Shape Layer',
            visible: layer.visible,
            locked: layer.locked
        }));
    },

    getLayer: (layerId) => {
        return layerHandles.get(layerId);
    },

    toggleLayerVisibility: (layerId) => {
        const layer = layerHandles.get(layerId);
        if (layer) {
            layer.visible = !layer.visible;
            // Update UI
            const layerTrack = document.querySelector(`.timeline-layer[data-layer-id="${layerId}"]`);
            if (layerTrack) {
                const visibilityBtn = layerTrack.querySelector('.layer-visibility');
                if (visibilityBtn) {
                    visibilityBtn.textContent = layer.visible ? '👁️' : '👁️‍🗨️';
                }
                layerTrack.classList.toggle('hidden', !layer.visible);
            }
        }
    },

    toggleLayerLock: (layerId) => {
        const layer = layerHandles.get(layerId);
        if (layer) {
            layer.locked = !layer.locked;
            // Update UI
            const layerTrack = document.querySelector(`.timeline-layer[data-layer-id="${layerId}"]`);
            if (layerTrack) {
                const lockBtn = layerTrack.querySelector('.layer-lock');
                if (lockBtn) {
                    lockBtn.textContent = layer.locked ? '🔒' : '🔓';
                }
                layerTrack.classList.toggle('locked', layer.locked);
            }
        }
    },

    createShapeLayer: () => {
        const layer = {
            id: Date.now(),
            type: 'shape',
            visible: true,
            locked: false,
            position: { x: 0, y: 0 },
            scale: { x: 1, y: 1 },
            rotation: 0,
            startTime: 0,
            duration: 0
        };
        
        layerHandles.set(layer.id, layer);
        return layer;
    },

    createTextLayer: (text) => {
        const layer = {
            id: Date.now(),
            type: 'text',
            content: text,
            visible: true,
            locked: false,
            position: { x: 0, y: 0 },
            scale: { x: 1, y: 1 },
            rotation: 0,
            startTime: 0,
            duration: 0,
            font: 'Arial',
            size: 24,
            color: '#ffffff'
        };
        
        layerHandles.set(layer.id, layer);
        return layer;
    },
};

// Layer management
const layerHandles = new Map();
const videoHandles = new Map();

const layerBindings = {
    getId: (handle) => {
        const layer = layerHandles.get(handle);
        return layer ? layer.id : 0;
    },
    
    getType: (handle) => {
        const layer = layerHandles.get(handle);
        return layer ? layer.type : null;
    },
    
    setVisible: (handle, visible) => {
        const layer = layerHandles.get(handle);
        if (layer) layer.visible = visible;
    },
    
    setLocked: (handle, locked) => {
        const layer = layerHandles.get(handle);
        if (layer) layer.locked = locked;
    },
    
    setPosition: (handle, x, y) => {
        const layer = layerHandles.get(handle);
        if (layer) layer.position = { x, y };
    },
    
    setScale: (handle, x, y) => {
        const layer = layerHandles.get(handle);
        if (layer) layer.scale = { x, y };
    },
    
    setRotation: (handle, angle) => {
        const layer = layerHandles.get(handle);
        if (layer) layer.rotation = angle;
    },
    
    setStartTime: (handle, time_ms) => {
        const layer = layerHandles.get(handle);
        if (layer) layer.startTime = time_ms;
    },
    
    getDuration: (handle) => {
        const layer = layerHandles.get(handle);
        return layer ? layer.duration : 0;
    },
    
    deinit: (handle) => {
        const layer = layerHandles.get(handle);
        if (layer) {
            if (layer.type === 'video') {
                layer.video.pause();
                URL.revokeObjectURL(layer.video.src);
            }
            layerHandles.delete(handle);
        }
    }
};

// Store WASM instance
let wasmInstance = null;

// Video processing functions
export const videoProcessing = {
    createVideoFromBlob: async (arrayBuffer, durationMs) => {
        console.log('Creating video from blob:', { size: arrayBuffer.byteLength, durationMs });
        const uint8Array = new Uint8Array(arrayBuffer);
        const blob = new Blob([uint8Array], { type: 'video/webm' });
        
        return new Promise((resolve, reject) => {
            const video = document.createElement('video');
            video.muted = true;
            video.preload = 'auto';
            
            const url = URL.createObjectURL(blob);
            
            const cleanup = () => {
                video.removeAttribute('src');
                video.load();
                URL.revokeObjectURL(url);
            };
            
            video.onloadeddata = () => {
                const handle = Date.now(); // Simple handle generation
                videoHandles.set(handle, {
                    video,
                    url,
                    duration: durationMs / 1000, // Convert to seconds
                    width: video.videoWidth || 1280, // Default if not available
                    height: video.videoHeight || 720  // Default if not available
                });
                console.log('Video loaded successfully:', {
                    duration: durationMs,
                    width: video.videoWidth,
                    height: video.videoHeight
                });
                resolve(handle);
            };
            
            video.onerror = () => {
                cleanup();
                reject(new Error(`Video load error: ${video.error?.message || 'Unknown error'}`));
            };
            
            video.src = url;
            video.load();
        });
    },
    
    getVideoMetadata: (handle) => {
        const videoData = videoHandles.get(handle);
        if (!videoData) {
            console.error('Video handle not found:', handle);
            return null;
        }
        
        const metadata = {
            duration_ms: Math.round(videoData.duration * 1000),
            width: videoData.width,
            height: videoData.height,
            frame_rate: 30 // Default frame rate
        };
        
        console.log('Video metadata:', metadata);
        return metadata;
    },
    
    createVideoLayer: (handle) => {
        const videoData = videoHandles.get(handle);
        if (!videoData) {
            console.error('Video handle not found:', handle);
            return null;
        }
        
        const layer = {
            id: Date.now(),
            type: 'video',
            video: videoData.video,
            url: videoData.url,
            visible: true,
            locked: false,
            position: { x: 0, y: 0 },
            scale: { x: 1, y: 1 },
            rotation: 0,
            startTime: 0,
            duration: Math.round(videoData.duration * 1000)
        };
        
        console.log('Creating video layer:', layer);
        layerHandles.set(layer.id, layer);

        // Create and add layer to timeline
        const timelineLayers = document.querySelector('.timeline-layers');
        if (timelineLayers) {
            const layerTrack = document.createElement('div');
            layerTrack.className = 'timeline-layer';
            layerTrack.dataset.layerId = layer.id;
            
            // Add styles to the layer track
            layerTrack.style.cssText = `
                background: #3d3d3d;
                border-radius: 4px;
                padding: 4px 8px;
                margin: 2px 0;
                display: flex;
                justify-content: space-between;
                align-items: center;
                height: 30px;
                cursor: pointer;
                user-select: none;
                transition: background-color 0.2s;
            `;
            
            layerTrack.innerHTML = `
                <div class="layer-label" style="font-size: 12px;">Video Layer (${Math.round(layer.duration / 1000)}s)</div>
                <div class="layer-controls" style="display: flex; gap: 4px;">
                    <button class="layer-visibility" title="Toggle visibility" style="background: none; border: none; color: white; cursor: pointer; padding: 2px;">👁️</button>
                    <button class="layer-lock" title="Toggle lock" style="background: none; border: none; color: white; cursor: pointer; padding: 2px;">🔓</button>
                </div>
            `;
            
            // Add event listeners for layer controls
            const visibilityBtn = layerTrack.querySelector('.layer-visibility');
            const lockBtn = layerTrack.querySelector('.layer-lock');
            
            visibilityBtn?.addEventListener('click', (e) => {
                e.stopPropagation();
                layer.visible = !layer.visible;
                visibilityBtn.textContent = layer.visible ? '👁️' : '👁️‍🗨️';
                layerTrack.classList.toggle('hidden', !layer.visible);
                // Trigger redraw
                const event = new CustomEvent('layerVisibilityChanged', { detail: { layerId: layer.id, visible: layer.visible } });
                document.dispatchEvent(event);
            });
            
            lockBtn?.addEventListener('click', (e) => {
                e.stopPropagation();
                layer.locked = !layer.locked;
                lockBtn.textContent = layer.locked ? '🔒' : '🔓';
                layerTrack.classList.toggle('locked', layer.locked);
            });
            
            // Add hover effect
            layerTrack.addEventListener('mouseenter', () => {
                layerTrack.style.backgroundColor = '#4d4d4d';
            });
            
            layerTrack.addEventListener('mouseleave', () => {
                layerTrack.style.backgroundColor = '#3d3d3d';
            });
            
            timelineLayers.appendChild(layerTrack);
        }

        // Show timeline if hidden
        const timeline = document.querySelector('.timeline');
        if (timeline) {
            timeline.style.display = 'block';
        }

        return layer.id;
    },
    
    drawLayers: (ctx, currentTime) => {
        for (const layer of layerHandles.values()) {
            if (!layer.visible) continue;
            
            ctx.save();
            ctx.translate(layer.position.x, layer.position.y);
            ctx.rotate(layer.rotation * Math.PI / 180);
            ctx.scale(layer.scale.x, layer.scale.y);
            
            if (layer.type === 'video' && layer.video) {
                const videoTime = (currentTime - layer.startTime) / 1000;
                if (videoTime >= 0 && videoTime <= layer.duration / 1000) {
                    // Use modulo to loop the video if needed
                    layer.video.currentTime = videoTime % layer.video.duration;
                    ctx.drawImage(layer.video, 0, 0, ctx.canvas.width, ctx.canvas.height);
                }
            }
            
            ctx.restore();
        }
    }
};

export default async function init() {
    if (wasmInstance) return wasmInstance;

    const response = await fetch('video_editor.wasm');
    const bytes = await response.arrayBuffer();
    const { instance } = await WebAssembly.instantiate(bytes, {
        wasi_snapshot_preview1: wasi,
        env: {
            ...envBindings,
            memory: envBindings.memory
        }
    });
    
    // Store memory for helper functions
    wasm = instance.exports;
    
    return wasm;
} 