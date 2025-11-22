extends PanelContainer

signal mode_changed(mode: String)

enum Mode {VIDEO, CAMERA, SUBTITLES, COMPOSITING, LAYERS, EFFECTS}
var current_mode: Mode = Mode.VIDEO

@onready var video_button = $VBoxContainer/VideoButton
@onready var camera_button = $VBoxContainer/CameraButton
@onready var subtitles_button = $VBoxContainer/SubtitlesButton
@onready var compositing_button = $VBoxContainer/CompositingButton
@onready var layers_button = $VBoxContainer/LayersButton
@onready var effects_button = $VBoxContainer/EffectsButton

func _ready():
    _update_button_states()

func _update_button_states():
    video_button.modulate = Color.WHITE
    camera_button.modulate = Color.WHITE
    subtitles_button.modulate = Color.WHITE
    compositing_button.modulate = Color.WHITE
    layers_button.modulate = Color.WHITE
    effects_button.modulate = Color.WHITE
    
    match current_mode:
        Mode.VIDEO:
            video_button.modulate = Color(0, 1, 0, 1)
        Mode.CAMERA:
            camera_button.modulate = Color(0, 1, 0, 1)
        Mode.SUBTITLES:
            subtitles_button.modulate = Color(0, 1, 0, 1)
        Mode.COMPOSITING:
            compositing_button.modulate = Color(0, 1, 0, 1)
        Mode.LAYERS:
            layers_button.modulate = Color(0, 1, 0, 1)
        Mode.EFFECTS:
            effects_button.modulate = Color(0, 1, 0, 1)

func _on_video_mode():
    current_mode = Mode.VIDEO
    _update_button_states()
    emit_signal("mode_changed", "video")

func _on_camera_mode():
    current_mode = Mode.CAMERA
    _update_button_states()
    emit_signal("mode_changed", "camera")

func _on_subtitles_mode():
    current_mode = Mode.SUBTITLES
    _update_button_states()
    emit_signal("mode_changed", "subtitles")

func _on_compositing_mode():
    current_mode = Mode.COMPOSITING
    _update_button_states()
    emit_signal("mode_changed", "compositing")

func _on_layers_mode():
    current_mode = Mode.LAYERS
    _update_button_states()
    emit_signal("mode_changed", "layers")

func _on_effects_mode():
    current_mode = Mode.EFFECTS
    _update_button_states()
    emit_signal("mode_changed", "effects") 