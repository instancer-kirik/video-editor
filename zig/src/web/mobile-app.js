class MobileVideoRecorder {
  constructor() {
    this.mediaRecorder = null;
    this.recordedChunks = [];
    this.currentStream = null;
    this.isRecording = false;
    this.isPaused = false;
    this.startTime = null;
    this.pauseTime = 0;
    this.recordingTimer = null;
    this.currentCamera = "user"; // 'user' for front, 'environment' for back
    this.currentZoom = 1;
    this.settings = {
      quality: "1080p",
      framerate: 30,
      format: "mp4",
    };
    this.wasmModule = null;
  }

  async initializeApp() {
    try {
      this.showLoading(true);
      this.setupEventListeners();
      await this.loadWasmModule();
      await this.enumerateCameras();
      await this.initializeCamera();
      this.showLoading(false);
      this.showToast("Camera ready!", "success");
    } catch (error) {
      console.error("Failed to initialize app:", error);
      this.showToast("Failed to initialize camera", "error");
      this.showLoading(false);
    }
  }

  async loadWasmModule() {
    try {
      // Load the WebAssembly module if available
      if (typeof WebAssembly !== "undefined") {
        const wasmResponse = await fetch("video-editor.wasm");
        if (wasmResponse.ok) {
          const wasmBytes = await wasmResponse.arrayBuffer();
          this.wasmModule = await WebAssembly.instantiate(wasmBytes, {
            env: {
              memory: new WebAssembly.Memory({ initial: 256, maximum: 256 }),
            },
          });
        }
      }
    } catch (error) {
      console.warn(
        "WASM module not available, using JavaScript fallbacks:",
        error,
      );
    }
  }

  setupEventListeners() {
    // Record button
    document.getElementById("record-button").addEventListener("click", () => {
      this.toggleRecording();
    });

    // Camera switch
    document
      .getElementById("switch-camera-button")
      .addEventListener("click", () => {
        this.switchCamera();
      });

    // Settings
    document.getElementById("settings-button").addEventListener("click", () => {
      this.toggleSettings();
    });

    document.getElementById("close-settings").addEventListener("click", () => {
      this.closeSettings();
    });

    // Grid toggle
    document.getElementById("grid-button").addEventListener("click", () => {
      this.toggleGrid();
    });

    // Flash toggle
    document.getElementById("flash-button").addEventListener("click", () => {
      this.toggleFlash();
    });

    // Zoom controls
    document
      .getElementById("zoom-1x")
      .addEventListener("click", () => this.setZoom(1));
    document
      .getElementById("zoom-2x")
      .addEventListener("click", () => this.setZoom(2));
    document
      .getElementById("zoom-5x")
      .addEventListener("click", () => this.setZoom(5));

    // Export button
    document.getElementById("export-button").addEventListener("click", () => {
      this.showExportModal();
    });

    // Export modal
    document.getElementById("export-cancel").addEventListener("click", () => {
      this.closeExportModal();
    });

    document.getElementById("export-save").addEventListener("click", () => {
      this.downloadVideo();
    });

    // Gallery button
    document.getElementById("gallery-button").addEventListener("click", () => {
      this.showGallery();
    });

    // Settings changes
    document
      .getElementById("quality-select")
      .addEventListener("change", (e) => {
        this.settings.quality = e.target.value;
        this.applySettings();
      });

    document
      .getElementById("framerate-select")
      .addEventListener("change", (e) => {
        this.settings.framerate = parseInt(e.target.value);
        this.applySettings();
      });

    document.getElementById("format-select").addEventListener("change", (e) => {
      this.settings.format = e.target.value;
    });

    document.getElementById("camera-select").addEventListener("change", (e) => {
      this.switchToCamera(e.target.value);
    });

    // Touch gestures for zoom
    let initialDistance = 0;
    let currentDistance = 0;

    const video = document.getElementById("camera-video");

    video.addEventListener("touchstart", (e) => {
      if (e.touches.length === 2) {
        e.preventDefault();
        initialDistance = this.getDistance(e.touches[0], e.touches[1]);
      }
    });

    video.addEventListener("touchmove", (e) => {
      if (e.touches.length === 2) {
        e.preventDefault();
        currentDistance = this.getDistance(e.touches[0], e.touches[1]);
        const scale = currentDistance / initialDistance;
        this.handlePinchZoom(scale);
      }
    });

    // Prevent default touch behaviors
    document.addEventListener(
      "touchmove",
      (e) => {
        if (e.scale !== 1) {
          e.preventDefault();
        }
      },
      { passive: false },
    );

    // Handle visibility change (app going to background)
    document.addEventListener("visibilitychange", () => {
      if (document.hidden && this.isRecording) {
        // Don't stop recording when app goes to background
        console.log("App went to background while recording");
      }
    });

    // Orientation change
    window.addEventListener("orientationchange", () => {
      setTimeout(() => this.handleOrientationChange(), 500);
    });

    // Battery optimization
    if ("navigator" in window && "getBattery" in navigator) {
      navigator.getBattery().then((battery) => {
        battery.addEventListener("levelchange", () => {
          if (battery.level < 0.1 && this.isRecording) {
            this.showToast(
              "Low battery - consider stopping recording",
              "error",
            );
          }
        });
      });
    }
  }

  async enumerateCameras() {
    try {
      const devices = await navigator.mediaDevices.enumerateDevices();
      const cameras = devices.filter((device) => device.kind === "videoinput");

      const cameraSelect = document.getElementById("camera-select");
      cameraSelect.innerHTML = "";

      cameras.forEach((camera, index) => {
        const option = document.createElement("option");
        option.value = camera.deviceId;
        option.textContent = camera.label || `Camera ${index + 1}`;
        cameraSelect.appendChild(option);
      });

      if (cameras.length === 0) {
        throw new Error("No cameras found");
      }
    } catch (error) {
      console.error("Failed to enumerate cameras:", error);
      throw error;
    }
  }

  async initializeCamera() {
    try {
      await this.stopCamera();

      const constraints = this.buildConstraints();
      this.currentStream =
        await navigator.mediaDevices.getUserMedia(constraints);

      const video = document.getElementById("camera-video");
      video.srcObject = this.currentStream;

      // Wait for video to be ready
      await new Promise((resolve) => {
        video.onloadedmetadata = resolve;
      });

      await video.play();

      // Apply zoom if needed
      if (this.currentZoom > 1) {
        this.applyZoom();
      }
    } catch (error) {
      console.error("Failed to initialize camera:", error);
      this.showToast("Camera access denied or unavailable", "error");
      throw error;
    }
  }

  buildConstraints() {
    const qualitySettings = {
      "4K": { width: 3840, height: 2160 },
      "1080p": { width: 1920, height: 1080 },
      "720p": { width: 1280, height: 720 },
      "480p": { width: 854, height: 480 },
    };

    const quality = qualitySettings[this.settings.quality];

    return {
      video: {
        facingMode: this.currentCamera,
        width: { ideal: quality.width },
        height: { ideal: quality.height },
        frameRate: { ideal: this.settings.framerate },
      },
      audio: {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
        sampleRate: 44100,
      },
    };
  }

  async toggleRecording() {
    if (this.isRecording) {
      await this.stopRecording();
    } else {
      await this.startRecording();
    }
  }

  async startRecording() {
    try {
      if (!this.currentStream) {
        throw new Error("No camera stream available");
      }

      // Reset recorded chunks
      this.recordedChunks = [];

      // Create MediaRecorder with optimal settings
      const mimeType = this.getBestMimeType();
      const options = {
        mimeType: mimeType,
        videoBitsPerSecond: this.getVideoBitrate(),
        audioBitsPerSecond: 128000,
      };

      this.mediaRecorder = new MediaRecorder(this.currentStream, options);

      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.recordedChunks.push(event.data);
        }
      };

      this.mediaRecorder.onstop = () => {
        this.onRecordingComplete();
      };

      this.mediaRecorder.onerror = (error) => {
        console.error("MediaRecorder error:", error);
        this.showToast("Recording error occurred", "error");
        this.resetRecordingState();
      };

      // Start recording
      this.mediaRecorder.start(1000); // Collect data every second
      this.isRecording = true;
      this.startTime = Date.now();
      this.pauseTime = 0;

      // Update UI
      this.updateRecordingUI(true);
      this.startTimer();

      this.showToast("Recording started", "success");

      // Wake lock to prevent screen from turning off
      this.requestWakeLock();
    } catch (error) {
      console.error("Failed to start recording:", error);
      this.showToast("Failed to start recording", "error");
      this.resetRecordingState();
    }
  }

  async stopRecording() {
    try {
      if (this.mediaRecorder && this.isRecording) {
        this.mediaRecorder.stop();
      }

      this.isRecording = false;
      this.stopTimer();
      this.updateRecordingUI(false);

      // Release wake lock
      this.releaseWakeLock();

      this.showToast("Recording stopped", "success");
    } catch (error) {
      console.error("Failed to stop recording:", error);
      this.showToast("Failed to stop recording", "error");
      this.resetRecordingState();
    }
  }

  onRecordingComplete() {
    if (this.recordedChunks.length === 0) {
      this.showToast("No video data recorded", "error");
      return;
    }

    // Show export button
    const exportButton = document.getElementById("export-button");
    exportButton.style.display = "flex";

    // Calculate final duration
    const duration = this.calculateRecordingDuration();
    this.showToast(`Video recorded: ${this.formatTime(duration)}`, "success");

    // Initialize WASM processing if available
    if (this.wasmModule) {
      this.processVideoWithWasm();
    }
  }

  getBestMimeType() {
    const formats = [
      "video/mp4;codecs=h264,aac",
      "video/webm;codecs=vp9,opus",
      "video/webm;codecs=vp8,opus",
      "video/webm",
      "video/mp4",
    ];

    for (const format of formats) {
      if (MediaRecorder.isTypeSupported(format)) {
        return format;
      }
    }

    return "video/webm"; // Fallback
  }

  getVideoBitrate() {
    const bitrateMap = {
      "4K": 20000000, // 20 Mbps
      "1080p": 8000000, // 8 Mbps
      "720p": 5000000, // 5 Mbps
      "480p": 2500000, // 2.5 Mbps
    };

    return bitrateMap[this.settings.quality] || 5000000;
  }

  async switchCamera() {
    try {
      this.currentCamera =
        this.currentCamera === "user" ? "environment" : "user";
      await this.initializeCamera();
      this.showToast(
        `Switched to ${this.currentCamera === "user" ? "front" : "back"} camera`,
        "success",
      );
    } catch (error) {
      console.error("Failed to switch camera:", error);
      this.showToast("Failed to switch camera", "error");
      // Revert camera setting
      this.currentCamera =
        this.currentCamera === "user" ? "environment" : "user";
    }
  }

  async switchToCamera(deviceId) {
    if (!deviceId) return;

    try {
      await this.stopCamera();

      const constraints = {
        video: {
          deviceId: { exact: deviceId },
          width: { ideal: 1920 },
          height: { ideal: 1080 },
          frameRate: { ideal: this.settings.framerate },
        },
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        },
      };

      this.currentStream =
        await navigator.mediaDevices.getUserMedia(constraints);
      const video = document.getElementById("camera-video");
      video.srcObject = this.currentStream;
      await video.play();

      this.showToast("Camera switched", "success");
    } catch (error) {
      console.error("Failed to switch to camera:", error);
      this.showToast("Failed to switch camera", "error");
      // Fallback to default camera
      await this.initializeCamera();
    }
  }

  setZoom(level) {
    this.currentZoom = level;
    this.updateZoomButtons();
    this.applyZoom();
  }

  updateZoomButtons() {
    document.querySelectorAll(".zoom-button").forEach((btn) => {
      btn.classList.remove("active");
    });
    document
      .getElementById(`zoom-${this.currentZoom}x`)
      .classList.add("active");
  }

  applyZoom() {
    const video = document.getElementById("camera-video");
    video.style.transform = `scale(${this.currentZoom})`;
  }

  handlePinchZoom(scale) {
    const newZoom = Math.max(1, Math.min(5, this.currentZoom * scale));
    if (newZoom !== this.currentZoom) {
      this.currentZoom = newZoom;
      this.applyZoom();
    }
  }

  getDistance(touch1, touch2) {
    const dx = touch1.clientX - touch2.clientX;
    const dy = touch1.clientY - touch2.clientY;
    return Math.sqrt(dx * dx + dy * dy);
  }

  toggleGrid() {
    const gridOverlay = document.getElementById("grid-overlay");
    const gridButton = document.getElementById("grid-button");

    gridOverlay.classList.toggle("visible");
    gridButton.classList.toggle("active");
  }

  async toggleFlash() {
    const flashButton = document.getElementById("flash-button");

    try {
      if (this.currentStream) {
        const videoTrack = this.currentStream.getVideoTracks()[0];
        const capabilities = videoTrack.getCapabilities();

        if (capabilities.torch) {
          const currentSettings = videoTrack.getSettings();
          const newTorchState = !currentSettings.torch;

          await videoTrack.applyConstraints({
            advanced: [{ torch: newTorchState }],
          });

          flashButton.classList.toggle("active", newTorchState);
          this.showToast(newTorchState ? "Flash on" : "Flash off", "success");
        } else {
          this.showToast("Flash not supported", "error");
        }
      }
    } catch (error) {
      console.error("Flash control failed:", error);
      this.showToast("Flash control failed", "error");
    }
  }

  toggleSettings() {
    const settingsPanel = document.getElementById("settings-panel");
    settingsPanel.classList.add("open");
  }

  closeSettings() {
    const settingsPanel = document.getElementById("settings-panel");
    settingsPanel.classList.remove("open");
  }

  async applySettings() {
    if (!this.isRecording) {
      try {
        await this.initializeCamera();
      } catch (error) {
        console.error("Failed to apply settings:", error);
        this.showToast("Failed to apply settings", "error");
      }
    }
  }

  showExportModal() {
    if (this.recordedChunks.length === 0) {
      this.showToast("No video to export", "error");
      return;
    }

    const modal = document.getElementById("export-modal");
    modal.classList.add("open");
    this.processVideoForExport();
  }

  closeExportModal() {
    const modal = document.getElementById("export-modal");
    modal.classList.remove("open");
  }

  async processVideoForExport() {
    const progressBar = document.getElementById("export-progress-bar");
    const messageElement = document.getElementById("export-message");
    const saveButton = document.getElementById("export-save");

    try {
      messageElement.textContent = "Processing video...";
      progressBar.style.width = "20%";

      // Create blob from recorded chunks
      const mimeType = this.getBestMimeType();
      this.videoBlob = new Blob(this.recordedChunks, { type: mimeType });

      progressBar.style.width = "60%";

      // Process with WASM if available
      if (this.wasmModule && this.videoBlob.size > 0) {
        await this.enhanceVideoWithWasm();
        progressBar.style.width = "90%";
      }

      progressBar.style.width = "100%";
      messageElement.textContent = "Video ready to save!";
      saveButton.style.display = "block";
    } catch (error) {
      console.error("Failed to process video:", error);
      messageElement.textContent = "Export failed. Try again.";
      this.showToast("Export processing failed", "error");
    }
  }

  async enhanceVideoWithWasm() {
    if (!this.wasmModule || !this.videoBlob) return;

    try {
      // Basic WASM processing - apply filters if configured
      const exports = this.wasmModule.instance.exports;

      // Initialize video editor
      exports.init_video_editor();

      // Apply basic enhancements
      exports.apply_brightness(1.1); // Slight brightness boost
      exports.apply_contrast(1.05); // Slight contrast boost
      exports.apply_saturation(1.02); // Slight saturation boost

      console.log("Video enhanced with WASM processing");
    } catch (error) {
      console.error("WASM video processing failed:", error);
    }
  }

  processVideoWithWasm() {
    if (!this.wasmModule) return;

    try {
      const exports = this.wasmModule.instance.exports;

      // Add a clip to the timeline
      const clipName = `Recording_${Date.now()}`;
      const namePtr = new TextEncoder().encode(clipName);
      const clipId = exports.add_clip(
        0.0,
        this.calculateRecordingDuration() / 1000,
        namePtr,
        namePtr.length,
        1,
      );

      console.log(`Added clip with ID: ${clipId}`);
    } catch (error) {
      console.error("WASM clip processing failed:", error);
    }
  }

  downloadVideo() {
    if (!this.videoBlob) {
      this.showToast("No video available", "error");
      return;
    }

    try {
      const url = URL.createObjectURL(this.videoBlob);
      const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
      const extension = this.settings.format === "mp4" ? "mp4" : "webm";
      const filename = `video_${timestamp}.${extension}`;

      // Create download link
      const downloadLink = document.createElement("a");
      downloadLink.href = url;
      downloadLink.download = filename;
      downloadLink.style.display = "none";

      document.body.appendChild(downloadLink);
      downloadLink.click();
      document.body.removeChild(downloadLink);

      // Clean up
      setTimeout(() => URL.revokeObjectURL(url), 1000);

      this.showToast("Video saved to downloads", "success");
      this.closeExportModal();

      // Hide export button
      document.getElementById("export-button").style.display = "none";
    } catch (error) {
      console.error("Failed to download video:", error);
      this.showToast("Failed to save video", "error");
    }
  }

  showGallery() {
    // This would open a gallery view of recorded videos
    // For now, just show a placeholder
    this.showToast("Gallery feature coming soon", "success");
  }

  startTimer() {
    this.recordingTimer = setInterval(() => {
      this.updateTimerDisplay();
    }, 100);
  }

  stopTimer() {
    if (this.recordingTimer) {
      clearInterval(this.recordingTimer);
      this.recordingTimer = null;
    }
  }

  updateTimerDisplay() {
    const elapsed = Date.now() - this.startTime - this.pauseTime;
    const timerDisplay = document.getElementById("timer-display");
    timerDisplay.textContent = this.formatTime(elapsed);
  }

  calculateRecordingDuration() {
    if (!this.startTime) return 0;
    const endTime = this.isRecording ? Date.now() : this.startTime;
    return endTime - this.startTime - this.pauseTime;
  }

  formatTime(milliseconds) {
    const totalSeconds = Math.floor(milliseconds / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes.toString().padStart(2, "0")}:${seconds.toString().padStart(2, "0")}`;
  }

  updateRecordingUI(isRecording) {
    const recordButton = document.getElementById("record-button");
    const recordingIndicator = document.getElementById("recording-indicator");

    if (isRecording) {
      recordButton.classList.add("recording");
      recordingIndicator.classList.add("active");
    } else {
      recordButton.classList.remove("recording");
      recordingIndicator.classList.remove("active");
    }
  }

  resetRecordingState() {
    this.isRecording = false;
    this.isPaused = false;
    this.startTime = null;
    this.pauseTime = 0;
    this.stopTimer();
    this.updateRecordingUI(false);
    this.releaseWakeLock();
  }

  async requestWakeLock() {
    try {
      if ("wakeLock" in navigator) {
        this.wakeLock = await navigator.wakeLock.request("screen");
        console.log("Screen wake lock activated");
      }
    } catch (error) {
      console.warn("Wake lock failed:", error);
    }
  }

  releaseWakeLock() {
    if (this.wakeLock) {
      this.wakeLock.release();
      this.wakeLock = null;
      console.log("Screen wake lock released");
    }
  }

  async stopCamera() {
    if (this.currentStream) {
      this.currentStream.getTracks().forEach((track) => {
        track.stop();
      });
      this.currentStream = null;
    }
  }

  handleOrientationChange() {
    // Recalibrate camera after orientation change
    if (this.currentStream && !this.isRecording) {
      setTimeout(async () => {
        try {
          await this.initializeCamera();
        } catch (error) {
          console.error(
            "Failed to reinitialize camera after orientation change:",
            error,
          );
        }
      }, 200);
    }
  }

  showLoading(show) {
    const loadingOverlay = document.getElementById("loading-overlay");
    if (show) {
      loadingOverlay.classList.add("visible");
    } else {
      loadingOverlay.classList.remove("visible");
    }
  }

  showToast(message, type = "success") {
    const toastContainer = document.getElementById("toast-container");

    const toast = document.createElement("div");
    toast.className = `toast ${type}`;
    toast.textContent = message;

    toastContainer.appendChild(toast);

    // Trigger animation
    setTimeout(() => toast.classList.add("show"), 100);

    // Remove toast after 3 seconds
    setTimeout(() => {
      toast.classList.remove("show");
      setTimeout(() => {
        if (toast.parentNode) {
          toastContainer.removeChild(toast);
        }
      }, 300);
    }, 3000);
  }

  // Cleanup method
  cleanup() {
    this.stopRecording();
    this.stopCamera();
    this.releaseWakeLock();

    if (this.recordingTimer) {
      clearInterval(this.recordingTimer);
    }
  }
}

// Initialize the app when DOM is loaded
document.addEventListener("DOMContentLoaded", async () => {
  window.videoRecorder = new MobileVideoRecorder();
  await window.videoRecorder.initializeApp();
});

// Handle app cleanup
window.addEventListener("beforeunload", () => {
  if (window.videoRecorder) {
    window.videoRecorder.cleanup();
  }
});

// Service Worker registration for PWA functionality
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker
      .register("sw.js")
      .then((registration) => {
        console.log("ServiceWorker registration successful");
      })
      .catch((error) => {
        console.log("ServiceWorker registration failed");
      });
  });
}

// Export for potential external use
export { MobileVideoRecorder };
