export const webBindings = {
    // Camera access
    getUserMedia: async (constraints) => {
        const stream = await navigator.mediaDevices.getUserMedia(constraints);
        return stream;
    },

    // MediaRecorder
    createMediaRecorder: (stream, options) => {
        return new MediaRecorder(stream, options);
    },

    // Canvas operations
    getCanvasContext: (canvas) => {
        return canvas.getContext('2d');
    },

    // DOM manipulation
    createElement: (tag) => document.createElement(tag),
    appendChild: (parent, child) => parent.appendChild(child),
};

export async function initCameraJS(constraints, callback) {
    try {
        const stream = await navigator.mediaDevices.getUserMedia({
            video: {
                width: constraints.video.width,
                height: constraints.video.height,
                frameRate: constraints.video.framerate,
            },
            audio: {
                echoCancellation: constraints.audio.echoCancellation,
                noiseSuppression: constraints.audio.noiseSuppression,
            }
        });
        
        // Convert stream to WASM handle
        const handle = createStreamHandle(stream);
        callback(handle, null);
    } catch (err) {
        let error;
        switch(err.name) {
            case 'NotAllowedError':
                error = CameraInitError.PermissionDenied;
                break;
            case 'NotFoundError':
                error = CameraInitError.DeviceNotFound;
                break;
            case 'NotSupportedError':
                error = CameraInitError.NotSupported;
                break;
            default:
                error = CameraInitError.Timeout;
        }
        callback(null, error);
    }
} 