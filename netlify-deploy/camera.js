export class CameraManager {
    constructor() {
        this.stream = null;
        this.devices = [];
        this.currentDeviceId = null;
        this.currentConstraints = null;
    }

    async initialize() {
        try {
            await this.enumerateDevices();
            return await this.setupCamera();
        } catch (error) {
            console.error('Camera initialization failed:', error);
            throw error;
        }
    }

    async enumerateDevices() {
        try {
            // Request initial permissions
            await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
            
            // Get list of devices
            const devices = await navigator.mediaDevices.enumerateDevices();
            this.devices = devices.filter(device => device.kind === 'videoinput');
            
            // Update camera select if it exists
            const cameraSelect = document.getElementById('camera-select');
            if (cameraSelect) {
                cameraSelect.innerHTML = this.devices.map(device => 
                    `<option value="${device.deviceId}">${device.label || `Camera ${this.devices.indexOf(device) + 1}`}</option>`
                ).join('');
                
                // Set current device ID
                this.currentDeviceId = cameraSelect.value;
            }
            
            return this.devices;
        } catch (error) {
            console.error('Failed to enumerate devices:', error);
            throw error;
        }
    }

    async setupCamera(deviceId = null, resolution = null, frameRate = null) {
        try {
            // Stop existing stream if any
            this.cleanup();

            // Get selected camera settings
            const cameraSelect = document.getElementById('camera-select');
            const resolutionSelect = document.getElementById('resolution-select');
            const framerateSelect = document.getElementById('framerate-select');

            deviceId = deviceId || (cameraSelect?.value);
            
            let [width, height] = [1280, 720]; // Default resolution
            if (resolution) {
                [width, height] = resolution;
            } else if (resolutionSelect) {
                [width, height] = resolutionSelect.value.split('x').map(Number);
            }

            const fps = frameRate || (framerateSelect ? Number(framerateSelect.value) : 30);

            this.currentConstraints = {
                video: {
                    deviceId: deviceId ? { exact: deviceId } : undefined,
                    width: { ideal: width },
                    height: { ideal: height },
                    frameRate: { ideal: fps }
                },
                audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true
                }
            };

            this.stream = await navigator.mediaDevices.getUserMedia(this.currentConstraints);
            this.currentDeviceId = deviceId;

            return this.stream;
        } catch (error) {
            console.error('Failed to setup camera:', error);
            throw error;
        }
    }

    async switchCamera(deviceId) {
        if (deviceId === this.currentDeviceId) return this.stream;
        return await this.setupCamera(deviceId);
    }

    async updateResolution(width, height) {
        return await this.setupCamera(this.currentDeviceId, [width, height]);
    }

    async updateFrameRate(fps) {
        return await this.setupCamera(this.currentDeviceId, null, fps);
    }

    cleanup() {
        if (this.stream) {
            this.stream.getTracks().forEach(track => track.stop());
            this.stream = null;
        }
    }

    getCurrentSettings() {
        if (!this.stream) return null;
        
        const videoTrack = this.stream.getVideoTracks()[0];
        if (!videoTrack) return null;
        
        const settings = videoTrack.getSettings();
        return {
            deviceId: settings.deviceId,
            width: settings.width,
            height: settings.height,
            frameRate: settings.frameRate,
            aspectRatio: settings.aspectRatio
        };
    }
}

export async function enumerateDevices() {
    const devices = await navigator.mediaDevices.enumerateDevices();
    return {
        video: devices.filter(d => d.kind === 'videoinput'),
        audio: devices.filter(d => d.kind === 'audioinput')
    };
} 