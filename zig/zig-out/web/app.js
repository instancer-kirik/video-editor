import { UIManager, RecordingUI } from './ui.js';
import { CameraManager } from './camera.js';
import init from './video_editor.js';
import { initWasm } from './bindings.js';

export class VideoEditorApp {
    constructor() {
        this.log('VideoEditorApp constructed');
        
        this.ui = new UIManager();
        this.recordingUI = new RecordingUI(
            () => this.startRecording(),
            () => this.stopRecording()
        );
        this.camera = new CameraManager();
        this.wasm = null;
        this.stream = null;
        this.mediaRecorder = null;
        this.recordedChunks = [];
        this.isRecording = false;
        this.recordingStartTime = 0;
        this.timerInterval = null;
        this.currentTime = 0;
        this.duration = 0;
        this.isPlaying = false;
        this.playbackRate = 1;
        this.layers = new Map();
        this.selectedLayer = null;
        this.trackPoints = new Map();
        this.editMode = false;
        this.currentTool = null;
        
        // Bind methods to maintain context
        this.startRecording = this.startRecording.bind(this);
        this.stopRecording = this.stopRecording.bind(this);
        this.startPlayback = this.startPlayback.bind(this);
        this.pausePlayback = this.pausePlayback.bind(this);
        this.updateTimer = this.updateTimer.bind(this);
        this.handleCanvasClick = this.handleCanvasClick.bind(this);
        this.handleCanvasMouseMove = this.handleCanvasMouseMove.bind(this);
        this.redrawCanvas = this.redrawCanvas.bind(this);
        
        // Initialize debug log
        const debugLog = document.getElementById('debug-log');
        if (!debugLog) {
            const log = document.createElement('div');
            log.id = 'debug-log';
            document.body.appendChild(log);
        }

        this.video = null;
        this.canvas = null;
        this.ctx = null;
        this.isDragging = false;
        this.animationFrameId = null;
        this.currentLayer = null;
        this.trackPoints = [];
        this.initializeUI();
        this.initializeTimeline();
        this.initializeWasm();
    }

    initializeUI() {
        // Initialize debug log
        this.debugLog = document.getElementById('debug-log');
        if (!this.debugLog) {
            this.debugLog = document.createElement('div');
            this.debugLog.id = 'debug-log';
            this.debugLog.style.display = 'block';
            document.body.appendChild(this.debugLog);
        }

        // Initialize loading overlay
        this.loadingOverlay = document.getElementById('loading-overlay');
        if (!this.loadingOverlay) {
            this.loadingOverlay = document.createElement('div');
            this.loadingOverlay.id = 'loading-overlay';
            this.loadingOverlay.className = 'loading-overlay';
            this.loadingOverlay.innerHTML = `
                <div class="loading-spinner"></div>
                <span id="loading-text">Initializing...</span>
            `;
            document.body.appendChild(this.loadingOverlay);
        }

        // Initialize canvas
        this.canvas = document.getElementById('preview-canvas');
        this.ctx = this.canvas.getContext('2d');

        // Initialize settings panel
        const settingsToggle = document.querySelector('.settings-toggle');
        const settingsPanel = document.querySelector('.settings-controls');
        if (settingsToggle && settingsPanel) {
            settingsToggle.addEventListener('click', () => {
                settingsPanel.classList.toggle('open');
                this.log('Settings panel ' + (settingsPanel.classList.contains('open') ? 'opened' : 'closed'));
            });
        }

        // Initialize edit mode
        const editModeButton = document.getElementById('edit-mode');
        if (editModeButton) {
            editModeButton.addEventListener('click', () => {
                this.editMode = !this.editMode;
                editModeButton.classList.toggle('active', this.editMode);
                this.canvas.classList.toggle('edit-mode', this.editMode);
                this.log(`Edit mode ${this.editMode ? 'enabled' : 'disabled'}`);
                
                // Show/hide edit controls
                const editControls = document.querySelector('.edit-controls');
                if (editControls) {
                    editControls.style.display = this.editMode ? 'flex' : 'none';
                }
            });
        }

        this.setupCameraControls();
        this.setupRecordingControls();

        // Initialize layers
        this.initializeLayers();
        this.initializeTextControls();

        // Initialize canvas interactions
        this.canvas.addEventListener('click', (e) => this.handleCanvasClick(e));
        this.canvas.addEventListener('mousemove', (e) => this.handleCanvasMouseMove(e));
    }

    initializeTimeline() {
        // Create timeline if it doesn't exist
        let timeline = document.querySelector('.timeline');
        if (!timeline) {
            timeline = document.createElement('div');
            timeline.className = 'timeline';
            timeline.style.display = 'none'; // Hide initially
            timeline.innerHTML = `
                <div class="timeline-controls">
                    <button id="play-pause" disabled>Play</button>
                    <span id="time-display">00:00 / 00:00</span>
                    <input type="range" id="playback-rate" min="0.25" max="2" step="0.25" value="1">
                    <span id="rate-display">1x</span>
                </div>
                <div class="timeline-track">
                    <div class="timeline-ruler"></div>
                    <div class="timeline-layers"></div>
                    <div class="timeline-progress"></div>
                    <div class="playhead"></div>
                </div>
            `;
            document.body.appendChild(timeline);

            // Add some basic styles
            timeline.style.cssText = `
                position: fixed;
                bottom: 0;
                left: 0;
                right: 0;
                background: #1e1e1e;
                color: white;
                padding: 10px;
                z-index: 1000;
            `;

            const timelineTrack = timeline.querySelector('.timeline-track');
            if (timelineTrack) {
                timelineTrack.style.cssText = `
                    position: relative;
                    height: 100px;
                    background: #2d2d2d;
                    margin-top: 10px;
                    border-radius: 4px;
                    overflow: hidden;
                `;
            }

            const timelineLayers = timeline.querySelector('.timeline-layers');
            if (timelineLayers) {
                timelineLayers.style.cssText = `
                    position: absolute;
                    top: 0;
                    left: 0;
                    right: 0;
                    bottom: 0;
                    display: flex;
                    flex-direction: column;
                    gap: 2px;
                    padding: 4px;
                `;
            }
        }

        // Initialize timeline controls
        this.setupTimelineControls();
    }

    setupTimelineControls() {
        const timeline = document.querySelector('.timeline');
        if (!timeline) return;

        const playPauseBtn = document.getElementById('play-pause');
        if (playPauseBtn) {
            playPauseBtn.addEventListener('click', () => this.togglePlayback());
            playPauseBtn.disabled = true; // Initially disabled until we have content
        }

        const timelineProgress = document.querySelector('.timeline-progress');
        if (timelineProgress) {
            timelineProgress.addEventListener('click', (e) => {
                const rect = timelineProgress.getBoundingClientRect();
                const position = (e.clientX - rect.left) / rect.width;
                this.seekToPosition(position);
            });
        }
    }

    togglePlayback() {
        this.isPlaying = !this.isPlaying;
        const playPauseBtn = document.getElementById('play-pause');
        if (playPauseBtn) {
            playPauseBtn.textContent = this.isPlaying ? 'Pause' : 'Play';
        }
        
        // Update video elements
        this.layers.forEach(layer => {
            if (layer.type === 'video' && layer.content) {
                if (this.isPlaying) {
                    layer.content.play().catch(console.error);
                } else {
                    layer.content.pause();
                }
            }
        });
        
        if (this.isPlaying) {
            this.startPlayback();
        } else {
            this.pausePlayback();
        }
    }

    startPlayback() {
        if (!this.isPlaying) return;

        // Use Zig for playback control
        if (this.wasm && this.wasm.updatePlayback) {
            this.wasm.updatePlayback(this.currentTime, this.playbackRate);
        }

        // Schedule next frame
        this.animationFrameId = requestAnimationFrame(() => {
            const frameDuration = 1000 / 60; // 60fps
            this.currentTime += frameDuration * this.playbackRate;
            
            if (this.currentTime >= this.duration) {
                this.currentTime = 0;
            }
            
            this.updateTimeDisplay();
            this.updatePlayhead();
            this.redrawCanvas();
            
            if (this.isPlaying) {
                this.startPlayback();
            }
        });
    }

    pausePlayback() {
        this.isPlaying = false;
        if (this.animationFrameId) {
            cancelAnimationFrame(this.animationFrameId);
            this.animationFrameId = null;
        }
    }

    seekToPosition(position) {
        this.currentTime = position * this.duration;
        
        // Update all video elements
        this.layers.forEach(layer => {
            if (layer.type === 'video' && layer.content) {
                layer.content.currentTime = (this.currentTime - layer.startTime) / 1000;
            }
        });
        
        this.updateTimeDisplay();
        this.updatePlayhead();
        this.redrawCanvas();
    }

    updatePlaybackRate() {
        // Update playback rate for all video layers
        this.layers.forEach(layer => {
            if (layer.type === 'video' && layer.content) {
                layer.content.playbackRate = this.playbackRate;
            }
        });
    }

    updateTimeDisplay() {
        const timeDisplay = document.getElementById('time-display');
        if (!timeDisplay) return;

        const formatTime = (ms) => {
            const totalSeconds = Math.floor(ms / 1000);
            const minutes = Math.floor(totalSeconds / 60);
            const seconds = totalSeconds % 60;
            return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
        };

        timeDisplay.textContent = `${formatTime(this.currentTime)} / ${formatTime(this.duration)}`;
    }

    updatePlayhead() {
        const playhead = document.querySelector('.playhead');
        if (!playhead) return;

        const position = (this.currentTime / this.duration) * 100;
        playhead.style.left = `${position}%`;
    }

    setupCameraControls() {
        // Camera switching
        const switchCameraButton = document.getElementById('swap-camera');
        if (switchCameraButton) {
            switchCameraButton.addEventListener('click', async () => {
                this.log('Switching camera...');
                await this.switchCamera();
            });
        }

        // Mute button
        const muteButton = document.getElementById('mute-button');
        if (muteButton) {
            muteButton.addEventListener('click', () => {
                if (this.stream) {
                    const audioTracks = this.stream.getAudioTracks();
                    audioTracks.forEach(track => {
                        track.enabled = !track.enabled;
                        const isMuted = !track.enabled;
                        muteButton.classList.toggle('muted', isMuted);
                        muteButton.querySelector('.unmuted').style.display = isMuted ? 'none' : 'inline';
                        muteButton.querySelector('.muted').style.display = isMuted ? 'inline' : 'none';
                        this.log(`Audio ${isMuted ? 'muted' : 'unmuted'}`);
                    });
                }
            });
        }
    }

    setupRecordingControls() {
        const recordButton = document.getElementById('record-button');
        const stopButton = document.getElementById('stop-button');
        const timerDisplay = document.getElementById('timer-display');

        if (!recordButton || !stopButton || !timerDisplay) {
            console.error('Recording controls not found');
            return;
        }

        // Show record button initially, hide stop button
        recordButton.style.display = 'block';
        stopButton.style.display = 'none';

        recordButton.addEventListener('click', async () => {
            try {
                await this.startRecording();
                recordButton.style.display = 'none';
                stopButton.style.display = 'block';
            } catch (error) {
                this.log('Failed to start recording:', error);
            }
        });

        stopButton.addEventListener('click', async () => {
            try {
                await this.stopRecording();
                recordButton.style.display = 'block';
                stopButton.style.display = 'none';
            } catch (error) {
                this.log('Failed to stop recording:', error);
            }
        });
    }

    setupPlaybackControls() {
        const playButton = document.getElementById('play-button');
        const pauseButton = document.getElementById('pause-button');
        const seekBackButton = document.getElementById('seek-back');
        const seekForwardButton = document.getElementById('seek-forward');

        if (!playButton || !pauseButton || !seekBackButton || !seekForwardButton) {
            console.error('Playback controls not found');
            return;
        }

        // Initially hide pause button, show play button
        playButton.style.display = 'block';
        pauseButton.style.display = 'none';

        playButton.addEventListener('click', () => {
            this.startPlayback();
            playButton.style.display = 'none';
            pauseButton.style.display = 'block';
        });

        pauseButton.addEventListener('click', () => {
            this.pausePlayback();
            playButton.style.display = 'block';
            pauseButton.style.display = 'none';
        });

        seekBackButton.addEventListener('click', () => {
            // Seek back 10 seconds
            this.seekToPosition(Math.max(0, this.currentTime - 10000));
        });

        seekForwardButton.addEventListener('click', () => {
            // Seek forward 10 seconds
            this.seekToPosition(Math.min(this.duration, this.currentTime + 10000));
        });
    }

    async startRecording() {
        if (this.isRecording) return;
        
        try {
            this.log('Starting recording...');
            
            this.recordedChunks = [];
            this.mediaRecorder = new MediaRecorder(this.stream, {
                mimeType: 'video/webm',
                videoBitsPerSecond: 2500000,
                audioBitsPerSecond: 128000
            });

            this.mediaRecorder.ondataavailable = (event) => {
                if (event.data.size > 0) {
                    this.recordedChunks.push(event.data);
                }
            };

            this.mediaRecorder.start(1000);
            this.recordingStartTime = Date.now();
            this.isRecording = true;
            this.log('Recording started');

        } catch (error) {
            this.showError(`Failed to start recording: ${error.message}`);
            this.isRecording = false;
        }
    }

    async stopRecording() {
        if (!this.isRecording) return;
        
        try {
            this.log('Stopping recording...');
            
            // Get the duration from our timer
            const recordingDuration = Date.now() - this.recordingStartTime;
            
            return new Promise((resolve, reject) => {
                this.mediaRecorder.onstop = async () => {
                    try {
                        const blob = new Blob(this.recordedChunks, { type: 'video/webm' });
                        const arrayBuffer = await blob.arrayBuffer();
                        const videoHandle = await this.wasm.createVideoFromBlob(arrayBuffer, recordingDuration);
                        
                        if (!videoHandle) {
                            throw new Error('Failed to create video handle');
                        }
                        
                        const layerHandle = await this.wasm.createVideoLayer(videoHandle);
                        if (!layerHandle) {
                            throw new Error('Failed to create video layer');
                        }
                        
                        this.log('Video layer created successfully');
                        resolve();
                    } catch (error) {
                        reject(error);
                    }
                };
                
                this.mediaRecorder.stop();
                this.isRecording = false;
            });
        } catch (error) {
            this.showError(`Failed to stop recording: ${error.message}`);
            this.isRecording = false;
            throw error;
        }
    }

    startTimer() {
        this.recordingStartTime = Date.now();
        this.updateTimer();
    }

    stopTimer() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
            this.timerInterval = null;
        }
    }

    updateTimer() {
        const timerDisplay = document.getElementById('timer-display');
        if (!timerDisplay) return;

        const updateDisplay = () => {
            const elapsed = Math.floor((Date.now() - this.recordingStartTime) / 1000);
            const minutes = Math.floor(elapsed / 60);
            const seconds = elapsed % 60;
            timerDisplay.textContent = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
        };

        // Update immediately and then every second
        updateDisplay();
        this.timerInterval = setInterval(updateDisplay, 1000);
    }

    async initialize() {
        this.log('Initializing application...');
        
        try {
            // Initialize camera first
            this.log('Initializing camera...');
            await this.camera.initialize();
            this.log('Camera initialized');
            
            // Initialize WASM module
            this.log('Initializing WASM module...');
            this.wasm = await init();
            if (!this.wasm) {
                throw new Error('Failed to initialize WASM module');
            }
            this.log('WASM module initialized');
            
            // Initialize the WASM app
            this.wasm.init();
            this.log('WASM app initialized');
            
            // Setup camera preview
            const stream = await this.camera.getStream();
            if (!stream) {
                throw new Error('Failed to get camera stream');
            }
            
            // Initialize preview
            const previewHandle = this.wasm.createPreviewHandle(this.canvas);
            if (!previewHandle) {
                throw new Error('Failed to create preview handle');
            }
            previewHandle.setVideoSource(stream);
            previewHandle.start();
            
            // Show recording controls
            this.recordingUI.show();
            
            this.log('Initialization complete');
        } catch (error) {
            this.log('ERROR: ' + error.message);
            throw error;
        }
    }

    async switchCamera() {
        try {
            this.showLoading('Switching camera...');
            
            // Stop current stream
            if (this.stream) {
                this.stream.getTracks().forEach(track => track.stop());
            }

            // Get list of video devices
            const devices = await navigator.mediaDevices.enumerateDevices();
            const videoDevices = devices.filter(device => device.kind === 'videoinput');
            
            // Find next camera
            const currentDevice = videoDevices.find(device => 
                this.stream && this.stream.getVideoTracks()[0].getSettings().deviceId === device.deviceId
            );
            const nextDevice = videoDevices[
                (videoDevices.indexOf(currentDevice) + 1) % videoDevices.length
            ];

            // Get current settings
            const resolution = document.getElementById('resolution-select').value;
            const [width, height] = resolution.split('x').map(Number);
            const frameRate = Number(document.getElementById('framerate-select').value);

            // Initialize new camera
            this.stream = await navigator.mediaDevices.getUserMedia({
                video: {
                    deviceId: nextDevice.deviceId,
                    width: { ideal: width },
                    height: { ideal: height },
                    frameRate: { ideal: frameRate }
                },
                audio: true
            });

            // Update video source
            this.video.srcObject = this.stream;
            await this.video.play();

            this.hideLoading();
            this.log('Camera switched successfully');
            
        } catch (error) {
            this.showError(`Failed to switch camera: ${error.message}`);
        }
    }

    log(message, ...args) {
        const timestamp = new Date().toLocaleTimeString();
        const formattedMessage = `[${timestamp}] ${message}`;
        console.log(formattedMessage, ...args);
        
        if (this.debugLog) {
            const logEntry = document.createElement('div');
            logEntry.textContent = formattedMessage;
            this.debugLog.appendChild(logEntry);
            
            // Keep only the last 50 messages
            while (this.debugLog.childNodes.length > 50) {
                this.debugLog.removeChild(this.debugLog.firstChild);
            }
            
            // Auto-scroll to bottom
            this.debugLog.scrollTop = this.debugLog.scrollHeight;
        }
    }

    showLoading(message) {
        if (this.loadingOverlay) {
            const loadingText = this.loadingOverlay.querySelector('#loading-text');
            if (loadingText) {
                loadingText.textContent = message;
            }
            this.loadingOverlay.style.display = 'flex';
        }
    }

    hideLoading() {
        if (this.loadingOverlay) {
            this.loadingOverlay.style.display = 'none';
        }
    }

    showError(message) {
        this.log('ERROR: ' + message);
        if (this.loadingOverlay) {
            this.loadingOverlay.classList.add('error');
            const loadingText = this.loadingOverlay.querySelector('#loading-text');
            if (loadingText) {
                loadingText.textContent = message;
            }
            this.loadingOverlay.style.display = 'flex';
            setTimeout(() => {
                this.loadingOverlay.style.display = 'none';
                this.loadingOverlay.classList.remove('error');
            }, 5000);
        }
    }

    cleanup() {
        this.camera?.cleanup();
        if (this.stream) {
            this.stream.getTracks().forEach(track => track.stop());
        }
        if (this.animationFrameId) {
        cancelAnimationFrame(this.animationFrameId);
        }
        if (this.video) {
            this.video.remove();
        }
    }

    initializeLayers() {
        // Create layers panel if it doesn't exist
        let layersPanel = document.querySelector('.layers-panel');
        if (!layersPanel) {
            layersPanel = document.createElement('div');
            layersPanel.className = 'layers-panel';
            layersPanel.innerHTML = `
                <div class="panel-header">
                    <h3>Layers</h3>
                    <button class="add-layer-btn">+</button>
                </div>
                <div class="layers-list"></div>
            `;
            document.body.appendChild(layersPanel);

            // Add layer button handler
            const addLayerBtn = layersPanel.querySelector('.add-layer-btn');
            addLayerBtn?.addEventListener('click', () => {
                const layerType = 'shape'; // Default to shape layer for now
                this.addLayer(layerType);
            });
        }
    }

    addLayer(type, content = null) {
        if (!this.wasm) return;

        let layer;
        switch (type) {
            case 'shape':
                layer = this.wasm.createShapeLayer();
                if (layer) {
                    this.log('Added new shape layer');
                }
                break;
            case 'text':
                layer = this.wasm.createTextLayer(content || 'New Text');
                if (layer) {
                    this.log('Added new text layer');
                    this.showTextPanel();
                }
                break;
        }

        if (layer) {
            this.currentLayer = layer;
            this.updateLayersList();
        }
    }

    updateLayersList() {
        const layersList = document.querySelector('.layers-list');
        if (!layersList || !this.wasm) return;

        // Get layers from WASM
        const layers = this.wasm.getLayers?.() || [];
        
        layersList.innerHTML = layers.map(layer => `
            <div class="layer-item ${layer.id === this.currentLayer?.id ? 'selected' : ''}" data-layer-id="${layer.id}">
                <span class="layer-name">${layer.name || `Layer ${layer.id}`}</span>
                <div class="layer-controls">
                    <button class="layer-visibility" title="Toggle visibility">
                        ${layer.visible ? '👁️' : '👁️‍🗨️'}
                    </button>
                    <button class="layer-lock" title="Toggle lock">
                        ${layer.locked ? '🔒' : '🔓'}
                    </button>
                </div>
            </div>
        `).join('');

        // Add event listeners
        layersList.querySelectorAll('.layer-item').forEach(item => {
            const layerId = parseInt(item.dataset.layerId);
            
            item.addEventListener('click', () => {
                this.selectLayer(layerId);
            });

            const visibilityBtn = item.querySelector('.layer-visibility');
            const lockBtn = item.querySelector('.layer-lock');

            visibilityBtn?.addEventListener('click', (e) => {
                e.stopPropagation();
                this.toggleLayerVisibility(layerId);
            });

            lockBtn?.addEventListener('click', (e) => {
                e.stopPropagation();
                this.toggleLayerLock(layerId);
            });
        });
    }

    selectLayer(layerId) {
        if (!this.wasm) return;
        const layer = this.wasm.getLayer?.(layerId);
        if (layer) {
            this.currentLayer = layer;
            this.updateLayersList();
            if (layer.type === 'text') {
                this.showTextPanel();
            } else {
                this.hideTextPanel();
            }
        }
    }

    toggleLayerVisibility(layerId) {
        if (!this.wasm) return;
        this.wasm.toggleLayerVisibility?.(layerId);
        this.updateLayersList();
        this.redrawCanvas();
    }

    toggleLayerLock(layerId) {
        if (!this.wasm) return;
        this.wasm.toggleLayerLock?.(layerId);
        this.updateLayersList();
    }

    initializeTextControls() {
        const textPanel = document.querySelector('.text-panel');
        if (!textPanel) return;

        // Text input handling
        const textInput = document.getElementById('text-input');
        textInput?.addEventListener('input', () => {
            if (this.currentLayer?.type === 'text') {
                this.currentLayer.content = textInput.value;
                this.redrawCanvas();
            }
        });

        // Font selection
        const fontSelect = document.getElementById('text-font');
        fontSelect?.addEventListener('change', () => {
            if (this.currentLayer?.type === 'text') {
                this.currentLayer.font = fontSelect.value;
                this.redrawCanvas();
            }
        });

        // Text size
        const sizeInput = document.getElementById('text-size');
        const sizeValue = document.querySelector('.size-value');
        sizeInput?.addEventListener('input', () => {
            if (this.currentLayer?.type === 'text') {
                this.currentLayer.size = parseInt(sizeInput.value);
                sizeValue.textContent = `${sizeInput.value}px`;
                this.redrawCanvas();
            }
        });

        // Color picker
        const colorInput = document.getElementById('text-color');
        colorInput?.addEventListener('input', () => {
            if (this.currentLayer?.type === 'text') {
                this.currentLayer.color = colorInput.value;
                this.redrawCanvas();
            }
        });

        // Style buttons
        document.querySelectorAll('.style-button').forEach(button => {
            button.addEventListener('click', () => {
                if (this.currentLayer?.type === 'text') {
                    const style = button.dataset.style;
                    this.currentLayer.styles = this.currentLayer.styles || {};
                    this.currentLayer.styles[style] = !this.currentLayer.styles[style];
                    button.classList.toggle('active');
                    this.redrawCanvas();
                }
            });
        });

        // Translation
        const translateButton = document.querySelector('.translate-button');
        translateButton?.addEventListener('click', () => {
            if (this.currentLayer?.type === 'text') {
                const targetLang = document.getElementById('text-language').value;
                this.translateText(this.currentLayer.content, targetLang);
            }
        });
    }

    async translateText(text, targetLang) {
        try {
            this.showLoading('Translating text...');
            // Here you would integrate with a translation API
            // For now, we'll just log the request
            this.log(`Translation requested: ${text} to ${targetLang}`);
            this.hideLoading();
        } catch (error) {
            this.showError(`Translation failed: ${error.message}`);
        }
    }

    showTextPanel() {
        const textPanel = document.querySelector('.text-panel');
        if (textPanel) {
            textPanel.style.display = 'block';
            // Update text panel with current layer settings
            if (this.currentLayer?.type === 'text') {
                document.getElementById('text-input').value = this.currentLayer.content || '';
                document.getElementById('text-font').value = this.currentLayer.font || 'Arial';
                document.getElementById('text-size').value = this.currentLayer.size || 24;
                document.getElementById('text-color').value = this.currentLayer.color || '#ffffff';
            }
        }
    }

    hideTextPanel() {
        const textPanel = document.querySelector('.text-panel');
        if (textPanel) {
            textPanel.style.display = 'none';
        }
    }

    redrawCanvas() {
        if (!this.ctx) return;

        // Clear canvas
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

        // Draw video frame if in camera mode
        if (!this.editMode && this.video && this.video.readyState === this.video.HAVE_ENOUGH_DATA) {
            this.ctx.drawImage(this.video, 0, 0, this.canvas.width, this.canvas.height);
        }

        // Draw layers using Zig
        if (this.wasm && this.wasm.drawLayers) {
            this.wasm.drawLayers(this.ctx, this.currentTime);
        }
    }

    handleCanvasClick(event) {
        if (!this.editMode) return;

        const rect = this.canvas.getBoundingClientRect();
        const x = (event.clientX - rect.left) / rect.width;
        const y = (event.clientY - rect.top) / rect.height;

        const selectedTool = document.querySelector('.tool-button.active')?.dataset.tool;
        if (selectedTool === 'track') {
            this.addTrackPoint(x, y);
        } else if (selectedTool === 'text') {
            this.addLayer('text');
            this.currentLayer.position = { x: event.clientX - rect.left, y: event.clientY - rect.top };
            this.showTextPanel();
            this.redrawCanvas();
        }
    }

    handleCanvasMouseMove(event) {
        if (!this.editMode || !this.currentLayer || this.currentLayer.locked) return;

        const rect = this.canvas.getBoundingClientRect();
        const x = event.clientX - rect.left;
        const y = event.clientY - rect.top;

        if (this.isDragging) {
            this.currentLayer.position = { x, y };
            this.redrawCanvas();
        }
    }

    addTrackPoint(x, y) {
        const point = {
            id: Date.now(),
            position: { x, y },
            frames: []
        };
        
        // Call Zig function to handle track point
        if (this.wasm && this.wasm.addTrackPoint) {
            this.wasm.addTrackPoint(x, y);
        }

        this.trackPoints.push(point);
        this.updateTrackPointsList();
        this.log(`Added track point at (${Math.round(x * 100)}%, ${Math.round(y * 100)}%)`);
    }

    async createVideoLayer(blob) {
        let video = null;
        let videoUrl = null;
        try {
            this.log('Creating video layer from blob...');
            video = document.createElement('video');
            video.muted = true;
            video.preload = 'auto'; // Force preload
            
            // Create object URL and set up video
            videoUrl = URL.createObjectURL(blob);
            this.log(`Created video URL: ${videoUrl}`);
            
            // Wait for video to be loaded
            let duration = null;
            let attempts = 0;
            const maxAttempts = 5;

            while (attempts < maxAttempts) {
                try {
                    await new Promise((resolve, reject) => {
                        const timeout = setTimeout(() => reject(new Error('Load timeout')), 3000);
                        
                        const handleCanPlay = () => {
                            clearTimeout(timeout);
                            if (video.duration && isFinite(video.duration)) {
                                duration = video.duration;
                                resolve();
                            } else {
                                reject(new Error('Invalid duration'));
                            }
                        };
                        
                        video.oncanplay = handleCanPlay;
                        video.onloadeddata = handleCanPlay;
                        
                        video.onerror = () => {
                            clearTimeout(timeout);
                            reject(new Error(`Load error: ${video.error?.message || 'Unknown error'}`));
                        };
                        
                        video.src = videoUrl;
                        video.load(); // Force load
                    });

                    if (duration !== null) {
                        this.log(`Video duration validated: ${duration}s`);
                        break;
                    }
                } catch (error) {
                    attempts++;
                    this.log(`Attempt ${attempts}/${maxAttempts} failed: ${error.message}`);
                    if (attempts === maxAttempts) {
                        throw new Error(`Failed to validate video after ${maxAttempts} attempts`);
                    }
                    // Wait longer between retries
                    await new Promise(resolve => setTimeout(resolve, 1000));
                }
            }
            
            // Ensure video is ready to play
            try {
                await video.play();
                video.pause();
                video.currentTime = 0;
            } catch (error) {
                this.log(`Warning: Video play failed: ${error.message}`);
                // Continue anyway as we just need the duration
            }
            
            const durationMs = Math.round(duration * 1000); // Convert to milliseconds
            this.log(`Creating layer with duration: ${durationMs}ms`);
            
            // Create and add the layer
            const layer = {
                id: Date.now(),
                type: 'video',
                name: `Video ${this.layers.length + 1}`,
                content: video,
                visible: true,
                position: { x: 0, y: 0 },
                scale: { x: 1, y: 1 },
                rotation: 0,
                startTime: 0,
                duration: durationMs,
                blob: blob
            };
            
            this.layers.push(layer);
            this.currentLayer = layer;
            this.duration = Math.max(this.duration, durationMs);
            
            // Add layer to timeline
            const layerTrack = document.createElement('div');
            layerTrack.className = 'timeline-layer';
            layerTrack.style.width = `${(durationMs / this.duration) * 100}%`;
            layerTrack.innerHTML = `
                <div class="layer-label">${layer.name} (${Math.round(durationMs / 1000)}s)</div>
                <div class="layer-controls">
                    <button class="layer-visibility" title="Toggle visibility">👁️</button>
                    <button class="layer-lock" title="Toggle lock">🔒</button>
                </div>
            `;
            
            const timelineLayers = document.querySelector('.timeline-layers');
            if (!timelineLayers) {
                throw new Error('Timeline layers container not found');
            }
            timelineLayers.appendChild(layerTrack);
            
            // Add event listeners for layer controls
            const visibilityBtn = layerTrack.querySelector('.layer-visibility');
            const lockBtn = layerTrack.querySelector('.layer-lock');
            
            visibilityBtn?.addEventListener('click', (e) => {
                e.stopPropagation();
                layer.visible = !layer.visible;
                visibilityBtn.textContent = layer.visible ? '👁️' : '👁️‍🗨️';
                layerTrack.classList.toggle('hidden', !layer.visible);
                this.redrawCanvas();
            });
            
            lockBtn?.addEventListener('click', (e) => {
                e.stopPropagation();
                layer.locked = !layer.locked;
                lockBtn.textContent = layer.locked ? '🔒' : '🔓';
                layerTrack.classList.toggle('locked', layer.locked);
            });
            
            this.updateLayersList();
            this.log(`Added video layer: ${layer.name} (${Math.round(durationMs / 1000)}s)`);
            
            // Show timeline
            const timeline = document.querySelector('.timeline');
            if (timeline) {
                timeline.style.display = 'block';
            }
            
            // Enable edit mode and timeline
            if (!this.editMode) {
                const editModeButton = document.getElementById('edit-mode');
                if (editModeButton) {
                    editModeButton.click();
                }
            }
            
            // Enable play button
            const playPauseBtn = document.getElementById('play-pause');
            if (playPauseBtn) {
                playPauseBtn.disabled = false;
            }
            
            // Start playback automatically
            this.isPlaying = true;
            this.startPlayback();
            
        } catch (error) {
            this.showError(`Failed to create video layer: ${error.message}`);
            // Clean up resources
            if (videoUrl) {
                URL.revokeObjectURL(videoUrl);
            }
            if (video) {
                video.remove();
            }
            throw error;
        }
    }

    setupEditControls() {
        const editControls = document.querySelector('.edit-controls');
        if (editControls) {
            editControls.querySelectorAll('.tool-button').forEach(button => {
                button.addEventListener('click', () => {
                    const tool = button.dataset.tool;
                    this.log(`Selected tool: ${tool}`);
                    // Deactivate all tools
                    editControls.querySelectorAll('.tool-button').forEach(b => 
                        b.classList.remove('active')
                    );
                    // Activate selected tool
                    button.classList.add('active');
                });
            });
        }
    }

    async initializeWasm() {
        try {
            const response = await fetch('video_editor.wasm');
            const wasmBytes = await response.arrayBuffer();
            const wasmModule = await WebAssembly.instantiate(wasmBytes, {
                env: {
                    // Add any required imports here
                }
            });
            
            this.wasm = initWasm(wasmModule.instance);
            console.log('WASM module initialized');
        } catch (err) {
            console.error('Failed to initialize WASM:', err);
        }
    }
}

// Initialize the app when the DOM is loaded
window.addEventListener('DOMContentLoaded', () => {
    window.videoEditor = new VideoEditorApp();
}); 