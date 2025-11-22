export class VideoEditor {
    constructor(canvas, ui) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.ui = ui;
        this.editMode = false;
        this.currentTool = null;
        this.layers = [];
        this.trackPoints = [];
        this.masks = [];
        this.effects = [];
        
        this.initializeEditControls();
    }

    initializeEditControls() {
        this.editControls = document.createElement('div');
        this.editControls.className = 'edit-controls';
        this.editControls.innerHTML = `
            <div class="tool-group">
                <button class="tool-button" data-tool="trim">Trim</button>
                <button class="tool-button" data-tool="crop">Crop</button>
                <button class="tool-button" data-tool="track">Track Point</button>
                <button class="tool-button" data-tool="mask">Mask</button>
            </div>
            <div class="tool-group">
                <button class="tool-button" data-tool="shape">Shape</button>
                <button class="tool-button" data-tool="effects">Effects</button>
            </div>
            <div class="layers-panel">
                <div class="panel-header">
                    <h3>Layers</h3>
                    <button class="add-layer">+ Add Layer</button>
                </div>
                <div class="layers-list"></div>
            </div>
            <div class="effects-panel" style="display: none;">
                <div class="panel-header">
                    <h3>Effects</h3>
                </div>
                <div class="effects-list">
                    <div class="effects-group">
                        <h4>Color</h4>
                        <button class="effect-button" data-effect="brightness">Brightness</button>
                        <button class="effect-button" data-effect="contrast">Contrast</button>
                        <button class="effect-button" data-effect="saturation">Saturation</button>
                    </div>
                    <div class="effects-group">
                        <h4>Filters</h4>
                        <button class="effect-button" data-effect="blur">Blur</button>
                        <button class="effect-button" data-effect="sharpen">Sharpen</button>
                        <button class="effect-button" data-effect="noise">Noise</button>
                    </div>
                    <div class="effects-group">
                        <h4>Stylize</h4>
                        <button class="effect-button" data-effect="vignette">Vignette</button>
                        <button class="effect-button" data-effect="grain">Film Grain</button>
                    </div>
                </div>
            </div>
            <div class="tracking-panel" style="display: none;">
                <div class="panel-header">
                    <h3>Track Points</h3>
                    <button class="add-track-point">+ Add Point</button>
                </div>
                <div class="track-points-list"></div>
                <button class="analyze-motion">Analyze Motion</button>
            </div>
            <div class="masking-panel" style="display: none;">
                <div class="panel-header">
                    <h3>Masking</h3>
                </div>
                <div class="mask-tools">
                    <button class="mask-tool" data-shape="rectangle">Rectangle</button>
                    <button class="mask-tool" data-shape="ellipse">Ellipse</button>
                    <button class="mask-tool" data-shape="polygon">Polygon</button>
                    <button class="mask-tool" data-shape="freehand">Freehand</button>
                </div>
                <div class="mask-options">
                    <label>
                        Feather:
                        <input type="range" min="0" max="100" value="0" class="feather-slider">
                    </label>
                    <label>
                        Opacity:
                        <input type="range" min="0" max="100" value="100" class="opacity-slider">
                    </label>
                </div>
            </div>
            <div class="timeline">
                <div class="timeline-ruler"></div>
                <div class="timeline-tracks"></div>
                <div class="timeline-playhead"></div>
            </div>
        `;
        
        document.body.appendChild(this.editControls);
        this.setupEventListeners();
    }

    setupEventListeners() {
        // Tool selection
        this.editControls.querySelectorAll('.tool-button').forEach(button => {
            button.addEventListener('click', () => {
                this.setActiveTool(button.dataset.tool);
            });
        });

        // Layer management
        const addLayerButton = this.editControls.querySelector('.add-layer');
        addLayerButton.addEventListener('click', () => this.addLayer());

        // Track point management
        const addTrackPointButton = this.editControls.querySelector('.add-track-point');
        addTrackPointButton.addEventListener('click', () => this.addTrackPoint());

        // Mask tools
        this.editControls.querySelectorAll('.mask-tool').forEach(button => {
            button.addEventListener('click', () => {
                this.setActiveMaskTool(button.dataset.shape);
            });
        });

        // Effect buttons
        this.editControls.querySelectorAll('.effect-button').forEach(button => {
            button.addEventListener('click', () => {
                this.applyEffect(button.dataset.effect);
            });
        });
    }

    setEditMode(active) {
        this.editMode = active;
        this.editControls.style.display = active ? 'flex' : 'none';
        this.canvas.classList.toggle('edit-mode', active);
        
        if (!active) {
            this.currentTool = null;
            this.hideAllPanels();
        }
    }

    setActiveTool(tool) {
        this.currentTool = tool;
        this.editControls.querySelectorAll('.tool-button').forEach(button => {
            button.classList.toggle('active', button.dataset.tool === tool);
        });

        // Show/hide relevant panels
        this.hideAllPanels();
        switch (tool) {
            case 'effects':
                this.editControls.querySelector('.effects-panel').style.display = 'block';
                break;
            case 'track':
                this.editControls.querySelector('.tracking-panel').style.display = 'block';
                break;
            case 'mask':
                this.editControls.querySelector('.masking-panel').style.display = 'block';
                break;
        }
    }

    hideAllPanels() {
        ['effects-panel', 'tracking-panel', 'masking-panel'].forEach(panel => {
            this.editControls.querySelector('.' + panel).style.display = 'none';
        });
    }

    addLayer() {
        const layer = {
            id: Date.now(),
            name: `Layer ${this.layers.length + 1}`,
            visible: true,
            locked: false,
            type: 'shape' // or 'video', 'image', 'text'
        };
        
        this.layers.push(layer);
        this.updateLayersList();
    }

    updateLayersList() {
        const layersList = this.editControls.querySelector('.layers-list');
        layersList.innerHTML = this.layers.map(layer => `
            <div class="layer-item" data-id="${layer.id}">
                <button class="visibility-toggle">${layer.visible ? '👁️' : '👁️‍🗨️'}</button>
                <button class="lock-toggle">${layer.locked ? '🔒' : '🔓'}</button>
                <span class="layer-name">${layer.name}</span>
            </div>
        `).join('');
    }

    addTrackPoint() {
        const point = {
            id: Date.now(),
            name: `Track Point ${this.trackPoints.length + 1}`,
            position: { x: 0, y: 0 },
            frames: []
        };
        
        this.trackPoints.push(point);
        this.updateTrackPointsList();
    }

    updateTrackPointsList() {
        const trackPointsList = this.editControls.querySelector('.track-points-list');
        trackPointsList.innerHTML = this.trackPoints.map(point => `
            <div class="track-point-item" data-id="${point.id}">
                <span class="point-name">${point.name}</span>
                <button class="analyze-point">Analyze</button>
            </div>
        `).join('');
    }

    setActiveMaskTool(shape) {
        this.editControls.querySelectorAll('.mask-tool').forEach(button => {
            button.classList.toggle('active', button.dataset.shape === shape);
        });
    }

    applyEffect(effect) {
        // Add effect to the effects array
        this.effects.push({
            id: Date.now(),
            type: effect,
            parameters: this.getDefaultEffectParameters(effect)
        });
        
        // Apply the effect to the canvas
        this.applyEffects();
    }

    getDefaultEffectParameters(effect) {
        switch (effect) {
            case 'brightness':
            case 'contrast':
            case 'saturation':
                return { value: 0 };
            case 'blur':
                return { radius: 5 };
            case 'sharpen':
                return { amount: 0.5 };
            case 'noise':
                return { amount: 0.1 };
            case 'vignette':
                return { size: 0.5, feather: 0.5 };
            case 'grain':
                return { amount: 0.2, size: 1.0 };
            default:
                return {};
        }
    }

    applyEffects() {
        // Apply all effects in sequence
        this.effects.forEach(effect => {
            switch (effect.type) {
                case 'brightness':
                    this.applyBrightnessEffect(effect.parameters);
                    break;
                case 'contrast':
                    this.applyContrastEffect(effect.parameters);
                    break;
                // Add other effect applications
            }
        });
    }

    applyBrightnessEffect(parameters) {
        const imageData = this.ctx.getImageData(0, 0, this.canvas.width, this.canvas.height);
        const d = imageData.data;
        const factor = 1 + parameters.value / 100;
        
        for (let i = 0; i < d.length; i += 4) {
            d[i] *= factor;     // red
            d[i + 1] *= factor; // green
            d[i + 2] *= factor; // blue
        }
        
        this.ctx.putImageData(imageData, 0, 0);
    }

    applyContrastEffect(parameters) {
        const imageData = this.ctx.getImageData(0, 0, this.canvas.width, this.canvas.height);
        const d = imageData.data;
        const factor = (259 * (parameters.value + 255)) / (255 * (259 - parameters.value));
        
        for (let i = 0; i < d.length; i += 4) {
            d[i] = factor * (d[i] - 128) + 128;     // red
            d[i + 1] = factor * (d[i + 1] - 128) + 128; // green
            d[i + 2] = factor * (d[i + 2] - 128) + 128; // blue
        }
        
        this.ctx.putImageData(imageData, 0, 0);
    }
} 