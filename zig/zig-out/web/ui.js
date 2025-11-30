export class UIManager {
    constructor() {
        this.initializeElements();
        this.setupEventListeners();
        this.isEditMode = false;
    }

    initializeElements() {
        // Main containers
        this.previewCanvas = document.getElementById('preview-canvas');
        this.timeline = document.querySelector('.timeline');
        this.layersContainer = document.querySelector('.layers-container');
        
        // Controls
        this.recordButton = document.getElementById('record-button');
        this.stopButton = document.getElementById('stop-button');
        this.playPauseButton = document.getElementById('play-pause');
        this.editModeButton = document.getElementById('edit-mode');
        
        // Camera controls
        this.cameraSelect = document.getElementById('camera-select');
        this.resolutionSelect = document.getElementById('resolution-select');
        this.framerateSelect = document.getElementById('framerate-select');
        
        // Status elements
        this.statusElement = document.getElementById('status');
        this.timerElement = document.getElementById('timer');
        this.loadingSpinner = document.getElementById('loading-spinner');
        
        // Initialize canvas context
        this.ctx = this.previewCanvas.getContext('2d');
    }

    setupEventListeners() {
        // Camera controls events
        if (this.cameraSelect) {
            this.cameraSelect.addEventListener('change', () => {
                this.dispatchEvent('cameraChange', this.cameraSelect.value);
            });
        }

        if (this.resolutionSelect) {
            this.resolutionSelect.addEventListener('change', () => {
                const [width, height] = this.resolutionSelect.value.split('x').map(Number);
                this.dispatchEvent('resolutionChange', { width, height });
            });
        }

        if (this.framerateSelect) {
            this.framerateSelect.addEventListener('change', () => {
                this.dispatchEvent('framerateChange', Number(this.framerateSelect.value));
            });
        }

        // Edit mode toggle
        if (this.editModeButton) {
            this.editModeButton.addEventListener('click', () => {
                this.toggleEditMode();
            });
        }
    }

    dispatchEvent(eventName, detail) {
        const event = new CustomEvent(eventName, { detail });
        window.dispatchEvent(event);
    }

    toggleEditMode() {
        this.isEditMode = !this.isEditMode;
        if (this.timeline) {
            this.timeline.style.display = this.isEditMode ? 'block' : 'none';
        }
        if (this.layersContainer) {
            this.layersContainer.style.display = this.isEditMode ? 'block' : 'none';
        }
        this.dispatchEvent('editModeChange', this.isEditMode);
    }

    showLoading(message) {
        if (this.loadingSpinner) {
            this.loadingSpinner.style.display = 'block';
        }
        this.log(message);
    }

    hideLoading() {
        if (this.loadingSpinner) {
            this.loadingSpinner.style.display = 'none';
        }
    }

    log(message, ...args) {
        const timestamp = new Date().toISOString();
        console.log(`[${timestamp}] ${message}`, ...args);
        
        if (this.statusElement) {
            this.statusElement.textContent = message;
        }
    }

    showError(message) {
        console.error(message);
        if (this.statusElement) {
            this.statusElement.textContent = `Error: ${message}`;
            this.statusElement.style.color = 'red';
        }
    }

    updateTimer(duration) {
        if (this.timerElement) {
            const minutes = Math.floor(duration / 60000);
            const seconds = Math.floor((duration % 60000) / 1000);
            const milliseconds = duration % 1000;
            this.timerElement.textContent = 
                `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}.${milliseconds.toString().padStart(3, '0')}`;
        }
    }

    clearTimer() {
        if (this.timerElement) {
            this.timerElement.textContent = '00:00.000';
        }
    }

    updateLayersList(layers) {
        if (!this.layersContainer) return;
        
        this.layersContainer.innerHTML = '';
        layers.forEach((layer, id) => {
            const layerElement = document.createElement('div');
            layerElement.className = 'layer';
            layerElement.textContent = `Layer ${id}`;
            layerElement.dataset.layerId = id;
            this.layersContainer.appendChild(layerElement);
        });
    }
}

export class RecordingUI {
    constructor(onStartRecording, onStopRecording) {
        this.onStartRecording = onStartRecording;
        this.onStopRecording = onStopRecording;
        this.recordButton = document.getElementById('record-button');
        this.stopButton = document.getElementById('stop-button');
        this.controlsContainer = document.querySelector('.recording-controls');
        this.setupEventListeners();
    }

    setupEventListeners() {
        if (this.recordButton) {
            this.recordButton.addEventListener('click', () => {
                this.recordButton.style.display = 'none';
                this.stopButton.style.display = 'block';
                this.onStartRecording();
            });
        }

        if (this.stopButton) {
            this.stopButton.addEventListener('click', () => {
                this.stopButton.style.display = 'none';
                this.recordButton.style.display = 'block';
                this.onStopRecording();
            });
        }
    }

    showRecordButton() {
        if (this.recordButton && this.stopButton) {
            this.recordButton.style.display = 'block';
            this.stopButton.style.display = 'none';
        }
    }

    showStopButton() {
        if (this.recordButton && this.stopButton) {
            this.recordButton.style.display = 'none';
            this.stopButton.style.display = 'block';
        }
    }

    show() {
        if (this.controlsContainer) {
            this.controlsContainer.style.display = 'flex';
            this.showRecordButton();
        }
    }

    hide() {
        if (this.controlsContainer) {
            this.controlsContainer.style.display = 'none';
        }
    }
} 