// Object handling
let objectId = 1;
const objects = new Map();
let memory = null;

// Constants for memory safety
const MAX_STRING_LENGTH = 16384; // 16KB max string length
const MAX_MEMORY_CHUNK = 1024 * 1024; // 1MB max chunk size

let wasm;

export function initBindings(wasmMemory) {
    console.log('Initializing bindings with WASM memory');
    memory = wasmMemory;
    if (!memory) {
        throw new Error('No WASM memory provided');
    }
    console.log('Memory buffer size:', memory.buffer.byteLength);
}

function __retain(obj) {
    if (!obj) {
        console.error('Attempting to retain null/undefined object');
        throw new Error('Cannot retain null/undefined object');
    }
    
    // Start IDs from 1, 0 is invalid
    const id = objectId++;
    if (id === 0) objectId++; // Skip 0
    
    objects.set(id, obj);
    console.log(`Retained object ${id}:`, obj);
    return id;
}

function __release(id) {
    if (objects.has(id)) {
        console.log(`Releasing object ${id}:`, objects.get(id));
        objects.delete(id);
    } else {
        console.warn(`Attempting to release non-existent object ${id}`);
    }
}

function __getObject(id) {
    // Explicitly check for 0
    if (id === 0) {
        console.error('Attempting to get object with invalid handle 0');
        throw new Error('Invalid object handle: 0');
    }
    
    const obj = objects.get(id);
    if (!obj) {
        console.error(`Object ${id} not found`);
        throw new Error(`Invalid object handle: ${id}`);
    }
    return obj;
}

function __call_function(ptr) {
    const fn = objects.get(ptr);
    if (typeof fn === 'function') {
        fn();
    }
}

function validateMemoryAccess(ptr, len) {
    if (!memory) throw new Error('WASM memory not initialized');
    
    // Basic sanity checks
    if (ptr < 0 || len < 0) {
        throw new Error(`Invalid memory access: negative ptr=${ptr} or len=${len}`);
    }
    
    if (len > MAX_STRING_LENGTH) {
        throw new Error(`String length ${len} exceeds maximum allowed length ${MAX_STRING_LENGTH}`);
    }
    
    if (len > MAX_MEMORY_CHUNK) {
        throw new Error(`Requested length ${len} exceeds maximum safe chunk size ${MAX_MEMORY_CHUNK}`);
    }

    const bufferSize = memory.buffer.byteLength;
    
    // Validate pointer is within bounds
    if (ptr >= bufferSize) {
        throw new Error(`Invalid memory pointer: ptr=${ptr} is beyond buffer size ${bufferSize}`);
    }
    
    // Check for potential overflow
    if (ptr + len > bufferSize) {
        throw new Error(`Memory access would overflow: ptr=${ptr} + len=${len} > buffer=${bufferSize}`);
    }
}

function decodeString(ptr, len) {
    // Handle empty strings
    if (!ptr || len === 0) return '';
    
    try {
        // Validate memory access before proceeding
        validateMemoryAccess(ptr, len);
        
        // Create a new view of the memory buffer
        const view = new Uint8Array(memory.buffer, ptr, len);
        
        // Find the actual string length by looking for null terminator
        let actualLen = 0;
        while (actualLen < len && view[actualLen] !== 0) actualLen++;
        
        // Only decode up to the null terminator or full length if none found
        const text = new TextDecoder().decode(view.subarray(0, actualLen));
        
        // Additional validation of decoded string
        if (text.length > MAX_STRING_LENGTH) {
            throw new Error(`Decoded string length ${text.length} exceeds maximum allowed length ${MAX_STRING_LENGTH}`);
        }
        
        return text;
    } catch (err) {
        console.error('Error decoding string:', err);
        console.error('Memory state:', { 
            ptr, 
            len, 
            bufferSize: memory.buffer.byteLength,
            memoryState: memory ? 'initialized' : 'null' 
        });
        throw err;
    }
}

export const webBindings = {
    // Object handling
    __retain,
    __release,
    __getObject,
    __call_function,

    // Camera access
    getUserMedia: async (constraints) => {
        console.log('Attempting to access camera with constraints:', constraints);
        try {
            const stream = await navigator.mediaDevices.getUserMedia(constraints);
            console.log('Camera access successful:', stream.getTracks().map(t => ({
                kind: t.kind,
                label: t.label,
                enabled: t.enabled,
                muted: t.muted,
                settings: t.getSettings()
            })));
            return stream;
        } catch (error) {
            console.error('Failed to get user media:', error);
            throw error;
        }
    },

    // MediaStream operations
    stop: (handle) => {
        console.log('Stopping media stream:', handle);
        const obj = __getObject(handle);
        if (obj && obj.stream) {
            obj.stream.getTracks().forEach(track => track.stop());
        }
        __release(handle);
    },

    getVideoTrack: (handle) => {
        console.log('Getting video track from stream:', handle);
        const obj = __getObject(handle);
        if (obj && obj.stream) {
            const track = obj.stream.getVideoTracks()[0];
            return track ? __retain(track) : null;
        }
        return null;
    },

    getAudioTrack: (handle) => {
        console.log('Getting audio track from stream:', handle);
        const obj = __getObject(handle);
        if (obj && obj.stream) {
            const track = obj.stream.getAudioTracks()[0];
            return track ? __retain(track) : null;
        }
        return null;
    },

    // Timer operations
    clear: (handle) => {
        console.log('Clearing timer:', handle);
        clearInterval(handle);
        __release(handle);
    },

    // Track operations
    enable: (handle) => {
        console.log('Enabling track:', handle);
        const track = __getObject(handle);
        if (track) track.enabled = true;
    },

    disable: (handle) => {
        console.log('Disabling track:', handle);
        const track = __getObject(handle);
        if (track) track.enabled = false;
    },

    // Resource cleanup
    deinit: (handle) => {
        console.log(`Deinitializing element ${handle}`);
        const element = __getObject(handle);
        if (element && element.parentNode) {
            element.parentNode.removeChild(element);
        }
        __release(handle);
    },

    // MediaRecorder operations
    startMediaRecorder: (handle) => {
        console.log('Starting media recorder:', handle);
        const recorder = __getObject(handle);
        if (recorder) recorder.start();
    },

    stopMediaRecorder: (handle) => {
        console.log('Stopping media recorder:', handle);
        const recorder = __getObject(handle);
        if (recorder) recorder.stop();
    },

    // Canvas operations
    getCanvasContext: (canvas) => {
        console.log('Getting canvas context');
        const ctx = canvas.getContext('2d');
        console.log('Canvas context:', ctx ? 'obtained' : 'failed');
        return ctx;
    },

    // DOM manipulation
    createElement: (tag_name) => {
        try {
            const tag = decodeString(tag_name);
            console.log('Creating element:', tag);
            
            // Validate tag name
            if (!tag || tag.length === 0) {
                throw new Error('Empty tag name');
            }
            
            // Create element
            const element = document.createElement(tag);
            if (!element) {
                throw new Error(`Failed to create element: ${tag}`);
            }
            
            // Retain and return handle
            const id = __retain(element);
            if (id === 0) {
                throw new Error('Failed to retain element');
            }
            
            console.log(`Created element ${id}:`, element);
            return id;
        } catch (err) {
            console.error('Error in createElement:', err);
            console.error('Tag name:', tag_name);
            throw err;
        }
    },

    appendChild: (parent_handle, child_handle) => {
        console.log(`Appending child ${child_handle} to parent ${parent_handle}`);
        const parent = __getObject(parent_handle);
        const child = __getObject(child_handle);
        if (!parent || !child) {
            console.error('Invalid parent or child handle:', { parent, child });
            throw new Error('Invalid parent or child handle');
        }
        parent.appendChild(child);
    },

    setAttribute: (handle, name, value) => {
        console.log(`Setting attribute on ${handle}:`, decodeString(name), '=', decodeString(value));
        const element = __getObject(handle);
        if (!element || typeof element.setAttribute !== 'function') {
            console.error('Invalid element handle or not a DOM element:', handle, element);
            throw new Error(`Invalid element handle: ${handle}`);
        }
        element.setAttribute(decodeString(name), decodeString(value));
    },

    setStyle: (handle, property, value) => {
        console.log(`Setting style on ${handle}:`, decodeString(property), '=', decodeString(value));
        const element = __getObject(handle);
        if (!element || !element.style) {
            console.error('Invalid element handle or not a DOM element:', handle, element);
            throw new Error(`Invalid element handle: ${handle}`);
        }
        element.style[decodeString(property)] = decodeString(value);
    },

    setSrcObject: (handle, stream_handle) => {
        console.log(`Setting srcObject on ${handle} with stream ${stream_handle}`);
        const element = __getObject(handle);
        const stream = __getObject(stream_handle);
        if (!element || !stream) {
            console.error('Invalid element or stream handle:', { element, stream });
            throw new Error('Invalid element or stream handle');
        }
        element.srcObject = stream;
    },

    play: (handle) => {
        console.log(`Playing video element ${handle}`);
        const element = __getObject(handle);
        if (!element || typeof element.play !== 'function') {
            console.error('Invalid video element handle:', handle, element);
            throw new Error(`Invalid video element handle: ${handle}`);
        }
        element.play().catch(err => {
            console.error('Error playing video:', err);
        });
    },

    addClass: (handle, class_name) => {
        console.log(`Adding class to ${handle}:`, decodeString(class_name));
        const element = __getObject(handle);
        if (!element || !element.classList) {
            console.error('Invalid element handle or not a DOM element:', handle, element);
            throw new Error(`Invalid element handle: ${handle}`);
        }
        element.classList.add(decodeString(class_name));
    },

    setText: (handle, text) => {
        console.log(`Setting text on ${handle}:`, decodeString(text));
        const element = __getObject(handle);
        if (!element) {
            console.error('Invalid element handle:', handle);
            throw new Error(`Invalid element handle: ${handle}`);
        }
        element.textContent = decodeString(text);
    },

    // Event handling
    addEventListener: (element, event, handler) => {
        console.log('Adding event listener:', event, 'to element:', element);
        element.addEventListener(event, handler);
    },
    
    // Timer functions
    setInterval: (callback, ms) => {
        console.log('Setting interval with ms:', ms);
        return setInterval(() => {
            __call_function(callback);
        }, ms);
    },
    clearInterval: (id) => {
        console.log('Clearing interval:', id);
        clearInterval(id);
    },

    // Add debug helper
    __debugObjects: () => {
        console.log('Current objects:');
        objects.forEach((obj, id) => {
            console.log(`ID ${id}:`, obj);
        });
    }
};

export async function initCameraJS(constraints) {
    console.log('Initializing camera with constraints:', constraints);
    try {
        const stream = await navigator.mediaDevices.getUserMedia({
            video: {
                width: { ideal: constraints.video.width },
                height: { ideal: constraints.video.height },
                frameRate: { ideal: constraints.video.framerate }
            },
            audio: {
                echoCancellation: constraints.audio.echoCancellation,
                noiseSuppression: constraints.audio.noiseSuppression,
            }
        });
        
        console.log('Camera stream obtained:', stream.getTracks().map(t => ({
            kind: t.kind,
            label: t.label,
            enabled: t.enabled,
            muted: t.muted,
            settings: t.getSettings()
        })));

        // Convert stream to WASM handle
        const handle = createStreamHandle(stream);
        // Call the WASM callback with success
        instance.exports.onCameraInitCallback(handle, 0); // 0 = CAMERA_ERROR_NONE
    } catch (err) {
        console.error('Camera initialization failed:', err);
        let errorCode;
        switch(err.name) {
            case 'NotAllowedError':
                errorCode = 1; // CAMERA_ERROR_PERMISSION_DENIED
                break;
            case 'NotFoundError':
                errorCode = 2; // CAMERA_ERROR_DEVICE_NOT_FOUND
                break;
            case 'NotSupportedError':
                errorCode = 3; // CAMERA_ERROR_NOT_SUPPORTED
                break;
            default:
                errorCode = 4; // CAMERA_ERROR_TIMEOUT
        }
        instance.exports.onCameraInitCallback(null, errorCode);
    }
}

// Helper function to create a stream handle that can be passed to WASM
function createStreamHandle(stream) {
    console.log('Creating stream handle');
    return __retain({
        stream,
        getVideoTrack: () => stream.getVideoTracks()[0],
        getAudioTrack: () => stream.getAudioTracks()[0],
        stop: () => {
            console.log('Stopping all tracks');
            stream.getTracks().forEach(track => track.stop());
        }
    });
}

export function initWasm(wasmModule) {
    wasm = wasmModule;
    return {
        processVideo,
        updateEffect,
        startRecording,
        stopRecording
    };
}

export function processVideo(videoBuffer) {
    const ptr = wasm.exports.allocateBuffer(videoBuffer.byteLength);
    const memory = new Uint8Array(wasm.exports.memory.buffer);
    memory.set(new Uint8Array(videoBuffer), ptr);
    
    const resultPtr = wasm.exports.processVideo(ptr, videoBuffer.byteLength);
    const resultSize = wasm.exports.getLastResultSize();
    
    const result = memory.slice(resultPtr, resultPtr + resultSize);
    wasm.exports.freeBuffer(ptr);
    wasm.exports.freeBuffer(resultPtr);
    
    return result.buffer;
}

export function updateEffect(effect, value) {
    switch (effect.toLowerCase()) {
        case 'brightness':
            wasm.exports.updateBrightness(value);
            break;
        case 'contrast':
            wasm.exports.updateContrast(value);
            break;
        case 'saturation':
            wasm.exports.updateSaturation(value);
            break;
    }
}

export function startRecording() {
    wasm.exports.startRecording();
}

export function stopRecording() {
    wasm.exports.stopRecording();
}

// Helper functions for memory management
export function allocateString(str) {
    const encoder = new TextEncoder();
    const bytes = encoder.encode(str);
    const ptr = wasm.exports.allocateBuffer(bytes.length + 1);
    const memory = new Uint8Array(wasm.exports.memory.buffer);
    memory.set(bytes, ptr);
    memory[ptr + bytes.length] = 0; // Null terminator
    return ptr;
}

export function readString(ptr) {
    const memory = new Uint8Array(wasm.exports.memory.buffer);
    let str = '';
    let i = ptr;
    while (memory[i] !== 0) {
        str += String.fromCharCode(memory[i]);
        i++;
    }
    return str;
}

// Error handling
export function getLastError() {
    const errorPtr = wasm.exports.getLastError();
    if (errorPtr === 0) return null;
    return readString(errorPtr);
} 