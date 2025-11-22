extends Control

# Node references
@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var timeline_editor: TimelineEditor = $TimelineEditor
@onready var like_button: Button = $Controls/LikeButton
@onready var sound_button: Button = $Controls/SoundButton
@onready var subtitles_button: Button = $Controls/SubtitlesButton
@onready var translate_button: Button = $Controls/TranslateButton
@onready var edit_button: Button = $Controls/EditButton
@onready var bookmark_button: Button = $Controls/BookmarkButton
@onready var share_button: Button = $Controls/ShareButton
@onready var comment_button: Button = $Controls/CommentButton
@onready var follow_button: Button = $Info/AuthorContainer/FollowButton
@onready var author_label: Label = $Info/AuthorContainer/AuthorLabel
@onready var description_label: Label = $Info/DescriptionLabel
@onready var sound_name: Label = $Info/SoundName
@onready var trim_preview: VideoStreamPlayer = $TrimPreview
@onready var subtitles_overlay: PanelContainer = $SubtitlesOverlay
@onready var subtitles_label: Label = $SubtitlesOverlay/SubtitlesLabel
@onready var translate_popup: PopupPanel = $TranslatePopup
@onready var language_list: ItemList = $TranslatePopup/TranslateOptions/LanguageList
@onready var camera_preview: TextureRect = $CameraPreview
@onready var camera_button: Button = $Controls/CameraButton
@onready var camera_viewport: SubViewport = $CameraViewport
@onready var camera_feed: Camera2D = $CameraViewport/CameraFeed

# Subtitle editor references
@onready var subtitle_editor: Panel = $SubtitleEditor
@onready var subtitle_list: ItemList = $SubtitleEditor/VBoxContainer/SubtitleList
@onready var add_subtitle_button: Button = $SubtitleEditor/VBoxContainer/Tools/AddButton
@onready var auto_gen_button: Button = $SubtitleEditor/VBoxContainer/Tools/AutoGenButton
@onready var import_button: Button = $SubtitleEditor/VBoxContainer/Tools/ImportButton
@onready var export_button: Button = $SubtitleEditor/VBoxContainer/Tools/ExportButton
@onready var start_time: SpinBox = $SubtitleEditor/VBoxContainer/EditContainer/TimeContainer/StartTime
@onready var end_time: SpinBox = $SubtitleEditor/VBoxContainer/EditContainer/TimeContainer/EndTime
@onready var subtitle_text: TextEdit = $SubtitleEditor/VBoxContainer/EditContainer/TextEdit
@onready var save_button: Button = $SubtitleEditor/VBoxContainer/EditContainer/ButtonContainer/SaveButton
@onready var delete_button: Button = $SubtitleEditor/VBoxContainer/EditContainer/ButtonContainer/DeleteButton

# Font settings references
@onready var font_family: OptionButton = $SubtitleEditor/VBoxContainer/FontSettings/Style/FontFamily/OptionButton
@onready var font_size: SpinBox = $SubtitleEditor/VBoxContainer/FontSettings/Style/FontSize/SpinBox
@onready var text_color: ColorPickerButton = $SubtitleEditor/VBoxContainer/FontSettings/Colors/TextColor/ColorPickerButton
@onready var outline_color: ColorPickerButton = $SubtitleEditor/VBoxContainer/FontSettings/Colors/OutlineColor/ColorPickerButton
@onready var bg_color: ColorPickerButton = $SubtitleEditor/VBoxContainer/FontSettings/Colors/BackgroundColor/ColorPickerButton
@onready var outline_size: SpinBox = $SubtitleEditor/VBoxContainer/FontSettings/Effects/OutlineSize/SpinBox
@onready var shadow_enabled: CheckBox = $SubtitleEditor/VBoxContainer/FontSettings/Effects/Shadow
@onready var vertical_position: OptionButton = $SubtitleEditor/VBoxContainer/FontSettings/Position/VerticalPosition/OptionButton

# Compositing references
@onready var tracking_mode: OptionButton = $SubtitleEditor/VBoxContainer/FontSettings/Compositing/TrackingMode/OptionButton
@onready var select_point_button: Button = $SubtitleEditor/VBoxContainer/FontSettings/Compositing/TrackingControls/Buttons/SelectTrackingPoint
@onready var start_tracking_button: Button = $SubtitleEditor/VBoxContainer/FontSettings/Compositing/TrackingControls/Buttons/StartTracking
@onready var clear_tracking_button: Button = $SubtitleEditor/VBoxContainer/FontSettings/Compositing/TrackingControls/Buttons/ClearTracking
@onready var x_offset: SpinBox = $SubtitleEditor/VBoxContainer/FontSettings/Compositing/TrackingControls/Offset/XOffset
@onready var y_offset: SpinBox = $SubtitleEditor/VBoxContainer/FontSettings/Compositing/TrackingControls/Offset/YOffset
@onready var motion_blur: CheckBox = $SubtitleEditor/VBoxContainer/FontSettings/Compositing/Effects/MotionBlur
@onready var perspective: CheckBox = $SubtitleEditor/VBoxContainer/FontSettings/Compositing/Effects/Perspective
@onready var scale_with_distance: CheckBox = $SubtitleEditor/VBoxContainer/FontSettings/Compositing/Effects/Scale
@onready var tracking_overlay: Control = $TrackingOverlay
@onready var tracking_point: ColorRect = $TrackingOverlay/TrackingPoint
@onready var tracking_box: ColorRect = $TrackingOverlay/TrackingBox

# Video feed reference
var video_feed: VideoFeed
var is_playing: bool = false
var current_speed: float = 1.0
var trim_start: float = 0.0
var trim_end: float = 0.0
var is_trimming: bool = false
var is_muted: bool = false
var subtitles_enabled: bool = false
var current_language: String = "en"

# Available languages for translation
var available_languages = {
	"en": "English",
	"es": "Spanish",
	"fr": "French",
	"de": "German",
	"it": "Italian",
	"ja": "Japanese",
	"ko": "Korean",
	"zh": "Chinese"
}

var current_subtitle_index: int = -1
var is_editing_subtitles: bool = false

# Font settings dictionary
var font_settings = {
	"family": "Default",
	"size": 24,
	"text_color": Color.WHITE,
	"outline_color": Color.BLACK,
	"outline_size": 2,
	"bg_color": Color(0, 0, 0, 0.5),
	"shadow": false,
	"position": "Bottom"
}

# Tracking state
var is_selecting_point: bool = false
var is_tracking: bool = false
var tracking_data = {
	"mode": "Static",
	"point": Vector2.ZERO,
	"box_size": Vector2(50, 50),
	"offset": Vector2.ZERO,
	"motion_blur": false,
	"perspective": false,
	"scale": false,
	"keyframes": {}  # Dictionary of frame -> position
}

# Layer and undo references
@onready var undo_button: Button = $SubtitleEditor/VBoxContainer/Tools/UndoButton
@onready var redo_button: Button = $SubtitleEditor/VBoxContainer/Tools/RedoButton
@onready var layer_list: ItemList = $SubtitleEditor/VBoxContainer/LayerContainer/LayerList
@onready var add_layer_button: Button = $SubtitleEditor/VBoxContainer/LayerContainer/Header/AddLayerButton
@onready var layer_options: PopupMenu = $SubtitleEditor/VBoxContainer/LayerContainer/LayerOptions
@onready var rename_dialog: PopupPanel = $SubtitleEditor/VBoxContainer/LayerContainer/RenameDialog
@onready var rename_input: LineEdit = $SubtitleEditor/VBoxContainer/LayerContainer/RenameDialog/VBoxContainer/LineEdit
@onready var rename_ok: Button = $SubtitleEditor/VBoxContainer/LayerContainer/RenameDialog/VBoxContainer/HBoxContainer/OKButton
@onready var rename_cancel: Button = $SubtitleEditor/VBoxContainer/LayerContainer/RenameDialog/VBoxContainer/HBoxContainer/CancelButton

# Layer management
class SubtitleLayer:
	var name: String
	var visible: bool
	var subtitles: Array
	var font_settings: Dictionary
	var tracking_data: Dictionary

	func _init(layer_name: String):
		name = layer_name
		visible = true
		subtitles = []
		font_settings = {}
		tracking_data = {}

	func duplicate() -> SubtitleLayer:
		var new_layer = SubtitleLayer.new(name + " Copy")
		new_layer.visible = visible
		new_layer.subtitles = subtitles.duplicate(true)
		new_layer.font_settings = font_settings.duplicate(true)
		new_layer.tracking_data = tracking_data.duplicate(true)
		return new_layer

# Undo system
class UndoAction:
	var action_type: String
	var layer_index: int
	var old_state: Dictionary
	var new_state: Dictionary

	func _init(type: String, index: int, old: Dictionary, new: Dictionary):
		action_type = type
		layer_index = index
		old_state = old
		new_state = new

var layers: Array[SubtitleLayer] = []
var current_layer_index: int = -1
var undo_stack: Array[UndoAction] = []
var redo_stack: Array[UndoAction] = []

# Layer management
class VideoLayer:
	var name: String
	var visible: bool
	var video_path: String
	var video_player: VideoStreamPlayer
	var blend_mode: String
	var opacity: float
	var transform: Transform2D
	var mask_type: String
	var mask_settings: Dictionary

	func _init(layer_name: String, path: String = ""):
		name = layer_name
		visible = true
		video_path = path
		blend_mode = "Normal"
		opacity = 1.0
		transform = Transform2D()
		mask_type = "None"
		mask_settings = {
			"type": "Alpha",
			"key_color": Color(0, 1, 0),
			"tolerance": 0.1,
			"feather": 0.0
		}

	func duplicate() -> VideoLayer:
		var new_layer = VideoLayer.new(name + " Copy", video_path)
		new_layer.visible = visible
		new_layer.blend_mode = blend_mode
		new_layer.opacity = opacity
		new_layer.transform = transform
		new_layer.mask_type = mask_type
		new_layer.mask_settings = mask_settings.duplicate()
		return new_layer

# Video layer references
@onready var video_layers_container: Control = $VideoLayers
@onready var mask_canvas: Control = $MaskCanvas
@onready var add_video_button: Button = $SubtitleEditor/VBoxContainer/LayerContainer/Header/AddVideoButton
@onready var add_mask_button: Button = $SubtitleEditor/VBoxContainer/LayerContainer/Header/AddMaskButton
@onready var blend_mode_menu: PopupMenu = $SubtitleEditor/VBoxContainer/LayerContainer/BlendModeMenu
@onready var opacity_slider: HSlider = $SubtitleEditor/VBoxContainer/LayerContainer/LayerProperties/VBoxContainer/Opacity/Slider
@onready var scale_x: SpinBox = $SubtitleEditor/VBoxContainer/LayerContainer/LayerProperties/VBoxContainer/Transform/ScaleX
@onready var scale_y: SpinBox = $SubtitleEditor/VBoxContainer/LayerContainer/LayerProperties/VBoxContainer/Transform/ScaleY
@onready var link_scale: Button = $SubtitleEditor/VBoxContainer/LayerContainer/LayerProperties/VBoxContainer/Transform/LinkScale
@onready var layer_rotation: SpinBox = $SubtitleEditor/VBoxContainer/LayerContainer/LayerProperties/VBoxContainer/Transform/Rotation
@onready var mask_type: OptionButton = $SubtitleEditor/VBoxContainer/LayerContainer/LayerProperties/VBoxContainer/MaskSettings/Type/OptionButton
@onready var key_color: ColorPickerButton = $SubtitleEditor/VBoxContainer/LayerContainer/LayerProperties/VBoxContainer/MaskSettings/ColorKey/ColorPicker
@onready var tolerance: HSlider = $SubtitleEditor/VBoxContainer/LayerContainer/LayerProperties/VBoxContainer/MaskSettings/Tolerance/Slider
@onready var feather: HSlider = $SubtitleEditor/VBoxContainer/LayerContainer/LayerProperties/VBoxContainer/MaskSettings/Feather/Slider

var video_layers: Array[VideoLayer] = []
var is_drawing_mask: bool = false
var mask_draw_points: Array = []

# Custom types
class CameraDriver:
	var device_index: int = -1
	var is_active: bool = false
	var frame_data: PackedByteArray
	var frame_image: Image
	var frame_texture: ImageTexture

	func _init():
		frame_image = Image.create(640, 480, false, Image.FORMAT_RGB8)
		frame_texture = ImageTexture.create_from_image(frame_image)

	func get_device_list() -> Array:
		var devices = []
		for i in range(10):
			var path = "/dev/video%d" % i
			if FileAccess.file_exists(path):
				devices.append(path)
		return devices

	func set_device(index: int) -> bool:
		device_index = index
		return true

	func start() -> bool:
		if device_index < 0:
			return false
		is_active = true
		return true

	func stop():
		is_active = false

	func get_frame() -> Image:
		return frame_image

# Camera variables
var camera_driver: CameraDriver = null
var is_camera_active: bool = false
var _debug: bool = true  # Add at the top with other variables

# Create icons for layer visibility
var visible_icon: Texture2D
var hidden_icon: Texture2D

func _ready():
	# Initialize video feed
	video_feed = get_node_or_null("/root/VideoFeed")

	# Connect signals only if nodes exist
	if video_feed:
		if video_feed.has_signal("video_changed"):
			video_feed.video_changed.connect(_on_video_changed)
		if video_feed.has_signal("trim_changed"):
			video_feed.trim_changed.connect(_on_trim_changed)
		if video_feed.has_signal("seek_position"):
			video_feed.seek_position.connect(_on_seek_position)
		if video_feed.has_signal("playback_speed_changed"):
			video_feed.playback_speed_changed.connect(_on_playback_speed_changed)

	# Initialize UI controls with null checks
	if font_family:
		font_family.item_selected.connect(_on_font_family_changed)
		font_settings["family"] = font_family.get_item_text(font_family.selected)

	if font_size:
		font_size.value_changed.connect(_on_font_size_changed)
		font_settings["size"] = int(font_size.value)

	if text_color:
		text_color.color_changed.connect(_on_text_color_changed)
		font_settings["text_color"] = text_color.color

	if outline_color:
		outline_color.color_changed.connect(_on_outline_color_changed)
		font_settings["outline_color"] = outline_color.color

	if bg_color:
		bg_color.color_changed.connect(_on_bg_color_changed)
		font_settings["bg_color"] = bg_color.color

	if outline_size:
		outline_size.value_changed.connect(_on_outline_size_changed)
		font_settings["outline_size"] = int(outline_size.value)

	if shadow_enabled:
		shadow_enabled.toggled.connect(_on_shadow_toggled)
		font_settings["shadow"] = shadow_enabled.button_pressed

	if vertical_position:
		vertical_position.item_selected.connect(_on_position_changed)
		font_settings["position"] = vertical_position.get_item_text(vertical_position.selected)

	# Initialize tracking controls
	if tracking_mode:
		tracking_mode.item_selected.connect(_on_tracking_mode_changed)
		tracking_data["mode"] = tracking_mode.get_item_text(tracking_mode.selected)

	if select_point_button:
		select_point_button.pressed.connect(_on_select_point_pressed)

	if start_tracking_button:
		start_tracking_button.pressed.connect(_on_start_tracking_pressed)

	if clear_tracking_button:
		clear_tracking_button.pressed.connect(_on_clear_tracking_pressed)

	if x_offset:
		x_offset.value_changed.connect(_on_x_offset_changed)
		tracking_data["offset"].x = x_offset.value

	if y_offset:
		y_offset.value_changed.connect(_on_y_offset_changed)
		tracking_data["offset"].y = y_offset.value

	if motion_blur:
		motion_blur.toggled.connect(_on_motion_blur_toggled)
		tracking_data["motion_blur"] = motion_blur.button_pressed

	if perspective:
		perspective.toggled.connect(_on_perspective_toggled)
		tracking_data["perspective"] = perspective.button_pressed

	if scale_with_distance:
		scale_with_distance.toggled.connect(_on_scale_toggled)
		tracking_data["scale"] = scale_with_distance.button_pressed

	# Initialize layer management
	if undo_button:
		undo_button.pressed.connect(_on_undo_pressed)

	if redo_button:
		redo_button.pressed.connect(_on_redo_pressed)

	if add_layer_button:
		add_layer_button.pressed.connect(_on_add_layer_pressed)

	if layer_options:
		layer_options.id_pressed.connect(_on_layer_option_selected)

	if rename_ok:
		rename_ok.pressed.connect(_on_rename_confirmed)

	if rename_cancel:
		rename_cancel.pressed.connect(_on_rename_canceled)

	# Connect video layer buttons
	if add_video_button:
		add_video_button.pressed.connect(_on_add_video_pressed)

	if add_mask_button:
		add_mask_button.pressed.connect(_on_add_mask_pressed)

	# Initialize tracking overlay
	if tracking_overlay:
		tracking_overlay.hide()
		if tracking_point:
			tracking_point.hide()
		if tracking_box:
			tracking_box.hide()

	# Apply initial font settings
	_apply_font_settings()

func _setup_language_list():
	language_list.clear()
	for code in available_languages:
		language_list.add_item(available_languages[code], null, false)
		language_list.set_item_metadata(language_list.get_item_count() - 1, code)

func _on_subtitles_pressed():
	subtitles_enabled = !subtitles_enabled
	subtitles_overlay.visible = subtitles_enabled
	subtitles_button.modulate = Color.WHITE if !subtitles_enabled else Color(0, 1, 0, 1)
	_update_subtitles()

func _on_translate_pressed():
	var popup_position = translate_button.global_position
	popup_position.y -= translate_popup.size.y
	translate_popup.position = popup_position
	translate_popup.popup()

func _on_language_selected(index: int):
	current_language = language_list.get_item_metadata(index)
	translate_popup.hide()
	_update_subtitles()

func _update_subtitles():
	if !subtitles_enabled:
		subtitles_overlay.hide()
		return

	var current_time = video_player.stream_position
	var visible_text = ""

	# Combine visible subtitles from all layers
	for layer in layers:
		if !layer.visible:
			continue

		for sub in layer.subtitles:
			if current_time >= sub.start_time and current_time < sub.end_time:
				if visible_text != "":
					visible_text += "\n"
				visible_text += sub.text

	if visible_text != "":
		subtitles_label.text = visible_text
		subtitles_overlay.show()
	else:
		subtitles_overlay.hide()

func _process(delta):
	if video_player and video_player.stream and is_playing:
		var current_pos = video_player.stream_position

		# Handle different stream types
		if video_player.stream is CameraStream:
			# Camera streams don't need timeline updates
			pass
		elif video_player.stream.has_method("get_length"):
			# Regular video files
			if timeline_editor and timeline_editor.position_indicator:
				timeline_editor.position_indicator.position.x = (current_pos / video_player.stream.get_length()) * timeline_editor.timeline.size.x

		# Loop playback within trim points
		if current_pos >= trim_end:
			video_player.seek(trim_start)

		# Update subtitles
		if subtitles_enabled:
			_update_subtitles()

		if is_tracking:
			_update_tracking()
			_update_subtitle_position()

	# Camera preview update
	if is_camera_active and camera_driver and camera_preview:
		var frame = camera_driver.get_frame()
		if frame:
			var texture = ImageTexture.create_from_image(frame)
			camera_preview.texture = texture
			# Also update video player if using camera stream
			if video_player and video_player.stream is CameraStream:
				video_player.texture = texture

func _load_video(video_data: VideoFeed.VideoData):
	if not video_player:
		push_error("Video player not found")
		return

	if not video_data or not video_data.stream:
		push_error("Invalid video data")
		return

	video_player.stream = video_data.stream
	video_player.paused = true
	is_playing = false

	# Handle different stream types
	if video_data.stream is CameraStream:
		# For camera streams, hide timeline and disable trimming
		if timeline_editor:
			timeline_editor.hide()
		trim_start = 0.0
		trim_end = 0.0
		# Start camera immediately
		video_player.paused = false
		is_playing = true
	elif video_data.stream.has_method("get_length"):
		# For regular video files
		if timeline_editor:
			timeline_editor.set_video_duration(video_data.stream.get_length())
			trim_start = 0.0
			trim_end = video_data.stream.get_length()

	# Update UI with null checks
	if author_label:
		author_label.text = video_data.author if video_data.author else "default"

	if description_label:
		description_label.text = video_data.description if video_data.description else "desc"

	if sound_name:
		sound_name.text = "♫ " + (video_data.sound_name if video_data.sound_name else "")

	if follow_button:
		follow_button.text = "Follow" if !video_data.is_following else "Following"

	if like_button:
		like_button.modulate = Color.WHITE if !video_data.is_liked else Color(1, 0, 0, 1)

	if bookmark_button:
		bookmark_button.modulate = Color.WHITE if !video_data.is_bookmarked else Color(1, 1, 0, 1)

func _on_like_pressed():
	video_feed.like_current_video()
	like_button.modulate = Color(1, 0, 0, 1)

func _on_sound_pressed():
	is_muted = !is_muted
	video_player.volume_db = -80.0 if is_muted else 0.0
	sound_button.text = "🔇" if is_muted else "🔊"

func _on_bookmark_pressed():
	video_feed.bookmark_current_video()
	bookmark_button.modulate = Color(1, 1, 0, 1)

func _on_share_pressed():
	# Implement share functionality
	pass

func _on_comment_pressed():
	# Implement comment functionality
	pass

func _on_follow_pressed():
	video_feed.toggle_follow_current_author()
	follow_button.text = "Following" if follow_button.text == "Follow" else "Follow"

func _on_video_changed(video_data: VideoFeed.VideoData):
	_load_video(video_data)

func _on_trim_changed(start_time: float, end_time: float):
	if not video_player or not video_player.stream:
		return

	# Seek to start time if current position is outside trim range
	var current_pos = video_player.get_playback_position()
	if current_pos < start_time or current_pos > end_time:
		video_player.seek(start_time)

func _on_seek_position(position: float):
	if not video_player or not video_player.stream:
		return

	video_player.seek(position)

func _on_playback_speed_changed(speed: float):
	current_speed = speed
	if video_player:
		video_player.playback_speed = speed

func toggle_playback():
	if not video_player or not video_player.stream:
		return

	is_playing = !is_playing
	video_player.paused = !is_playing

# Enhanced dragging support
func _on_drag_started():
	is_trimming = true
	trim_preview.show()
	trim_preview.stream = video_player.stream
	video_player.paused = true

func _on_drag_ended():
	is_trimming = false
	trim_preview.hide()
	video_player.paused = false
	video_player.seek(trim_preview.stream_position)

# Export trimmed video
func export_trimmed_video():
	# Here you would implement video export functionality
	# This could involve FFmpeg or other video processing tools
	pass

# Handle swipe gestures for next/previous video
var swipe_start = Vector2()
var minimum_drag = 50

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			swipe_start = event.position
		else:
			_check_swipe(event.position)

	if is_selecting_point and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_pos = tracking_overlay.get_local_mouse_position()
			tracking_data["point"] = local_pos
			tracking_point.position = local_pos
			tracking_box.position = local_pos - tracking_data["box_size"] / 2
			is_selecting_point = false
			video_player.paused = false
			_update_subtitle_position()

	if event.is_action_pressed("ui_undo"):
		_on_undo_pressed()
	elif event.is_action_pressed("ui_redo"):
		_on_redo_pressed()

	if is_drawing_mask and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mask_draw_points.append(mask_canvas.get_local_mouse_position())
			else:
				is_drawing_mask = false
				_apply_mask(video_layers[current_layer_index])
	elif is_drawing_mask and event is InputEventMouseMotion:
		mask_draw_points.append(mask_canvas.get_local_mouse_position())
		queue_redraw()

func _check_swipe(end_position: Vector2):
	var swipe = end_position - swipe_start
	if abs(swipe.y) > minimum_drag:
		if swipe.y > 0:
			video_feed.previous_video()
		else:
			video_feed.next_video()

func _on_edit_button_pressed():
	is_editing_subtitles = !is_editing_subtitles
	subtitle_editor.visible = is_editing_subtitles
	edit_button.modulate = Color.WHITE if !is_editing_subtitles else Color(0, 1, 0, 1)
	if is_editing_subtitles:
		_refresh_subtitle_list()

func _refresh_subtitle_list():
	subtitle_list.clear()
	var current_video = video_feed.get_current_video()
	if !current_video or !current_video.subtitles.has(current_language):
		return

	var subs = current_video.subtitles[current_language]
	for i in range(subs.size()):
		var sub = subs[i]
		var time_text = "%0.1f-%0.1f: %s" % [sub.start_time, sub.end_time, sub.text]
		subtitle_list.add_item(time_text)

func _on_add_subtitle():
	var current_time = video_player.stream_position
	start_time.value = current_time
	end_time.value = current_time + 2.0
	subtitle_text.text = ""
	current_subtitle_index = -1

func _on_auto_generate():
	# Here you would implement AI-based subtitle generation
	# For now, we'll add a placeholder message
	OS.alert("Auto-generation would use AI to create subtitles\nThis feature requires integration with a speech-to-text service.")

func _on_import_srt():
	# Here you would implement SRT file import
	# This would parse an SRT file and add the subtitles
	OS.alert("SRT import would allow loading subtitles from a file")

func _on_export_srt():
	# Here you would implement SRT file export
	# This would format the subtitles as an SRT file
	OS.alert("SRT export would save subtitles to a file")

func _on_save_subtitle():
	if current_layer_index < 0:
		return

	var layer = layers[current_layer_index]
	var old_subtitles = layer.subtitles.duplicate(true)

	var new_sub = VideoFeed.SubtitleEntry.new(
		start_time.value,
		end_time.value,
		subtitle_text.text
	)

	if current_subtitle_index >= 0 and current_subtitle_index < layer.subtitles.size():
		layer.subtitles[current_subtitle_index] = new_sub
	else:
		layer.subtitles.append(new_sub)

	_record_action("edit_subtitle", current_layer_index,
		{"subtitles": old_subtitles},
		{"subtitles": layer.subtitles.duplicate(true)})

	_refresh_subtitle_list()

func _on_delete_subtitle():
	var current_video = video_feed.get_current_video()
	if !current_video or !current_video.subtitles.has(current_language):
		return

	var subs = current_video.subtitles[current_language]
	if current_subtitle_index >= 0 and current_subtitle_index < subs.size():
		subs.remove_at(current_subtitle_index)
		_refresh_subtitle_list()
		current_subtitle_index = -1
		start_time.value = 0
		end_time.value = 0
		subtitle_text.text = ""

func _on_subtitle_selected(index: int):
	current_subtitle_index = index
	var current_video = video_feed.get_current_video()
	if !current_video or !current_video.subtitles.has(current_language):
		return

	var subs = current_video.subtitles[current_language]
	if index >= 0 and index < subs.size():
		var sub = subs[index]
		start_time.value = sub.start_time
		end_time.value = sub.end_time
		subtitle_text.text = sub.text
		video_player.seek(sub.start_time)

func _apply_font_settings():
	if not subtitles_label:
		return

	# Create label settings if it doesn't exist
	if not subtitles_label.label_settings:
		subtitles_label.label_settings = LabelSettings.new()

	var label_settings = subtitles_label.label_settings

	# Create and configure font
	var system_font = SystemFont.new()

	# Apply font family
	match font_settings["family"]:
		"Default":
			# Use system default font
			pass
		"Casual":
			system_font.font_names = PackedStringArray(["Comic Sans MS", "Arial"])
		"Monospace":
			system_font.font_names = PackedStringArray(["Courier New", "DejaVu Sans Mono"])
		"Handwriting":
			system_font.font_names = PackedStringArray(["Segoe Script", "Comic Sans MS"])

	# Apply settings to label
	label_settings.font = system_font
	label_settings.font_size = int(font_settings["size"])  # Set font size on label_settings, not on font
	label_settings.font_color = font_settings["text_color"]
	label_settings.outline_size = font_settings["outline_size"]
	label_settings.outline_color = font_settings["outline_color"]

	# Apply shadow if enabled
	if font_settings["shadow"]:
		label_settings.shadow_size = 4
		label_settings.shadow_color = Color(0, 0, 0, 0.5)
	else:
		label_settings.shadow_size = 0

	# Apply background color if panel style exists
	if subtitles_overlay and subtitles_overlay.has_theme_stylebox("panel"):
		var style = subtitles_overlay.get_theme_stylebox("panel")
		if style:
			style.bg_color = font_settings["bg_color"]
			style.set_meta("visible", font_settings["bg_color"].a > 0)

	# Apply vertical alignment
	if subtitles_overlay:
		match font_settings["position"]:
			"Top":
				subtitles_overlay.anchor_top = 0.0
				subtitles_overlay.anchor_bottom = 0.0
				subtitles_overlay.offset_top = 20.0
				subtitles_overlay.offset_bottom = 60.0
			"Middle":
				subtitles_overlay.anchor_top = 0.5
				subtitles_overlay.anchor_bottom = 0.5
				subtitles_overlay.offset_top = -20.0
				subtitles_overlay.offset_bottom = 20.0
			"Bottom":
				subtitles_overlay.anchor_top = 1.0
				subtitles_overlay.anchor_bottom = 1.0
				subtitles_overlay.offset_top = -200.0
				subtitles_overlay.offset_bottom = -160.0

func _on_font_family_changed(index: int):
	if font_family:
		font_settings["family"] = font_family.get_item_text(index)
		_apply_font_settings()

func _on_font_size_changed(value: float):
	font_settings["size"] = int(value)
	_apply_font_settings()

func _on_text_color_changed(color: Color):
	font_settings["text_color"] = color
	_apply_font_settings()

func _on_outline_color_changed(color: Color):
	font_settings["outline_color"] = color
	_apply_font_settings()

func _on_bg_color_changed(color: Color):
	font_settings["bg_color"] = color
	_apply_font_settings()

func _on_outline_size_changed(value: float):
	font_settings["outline_size"] = int(value)
	_apply_font_settings()

func _on_shadow_toggled(enabled: bool):
	font_settings["shadow"] = enabled
	_apply_font_settings()

func _on_position_changed(index: int):
	if vertical_position:
		font_settings["position"] = vertical_position.get_item_text(index)
		_apply_font_settings()

func _on_tracking_mode_changed(index: int):
	tracking_data["mode"] = tracking_mode.get_item_text(index)
	_update_tracking_ui()

func _on_select_point_pressed():
	is_selecting_point = true
	tracking_overlay.show()
	tracking_point.show()
	tracking_box.show()
	video_player.paused = true

func _on_start_tracking_pressed():
	if tracking_data["mode"] != "Static":
		is_tracking = true
		_start_tracking()

func _on_clear_tracking_pressed():
	is_tracking = false
	tracking_data["keyframes"].clear()
	tracking_point.position = tracking_data["point"]
	tracking_box.position = tracking_data["point"] - tracking_data["box_size"] / 2
	_update_subtitle_position()

func _on_x_offset_changed(value: float):
	tracking_data["offset"].x = value
	_update_subtitle_position()

func _on_y_offset_changed(value: float):
	tracking_data["offset"].y = value
	_update_subtitle_position()

func _on_motion_blur_toggled(enabled: bool):
	tracking_data["motion_blur"] = enabled
	_update_subtitle_effects()

func _on_perspective_toggled(enabled: bool):
	tracking_data["perspective"] = enabled
	_update_subtitle_effects()

func _on_scale_toggled(enabled: bool):
	tracking_data["scale"] = enabled
	_update_subtitle_effects()

func _start_tracking():
	var current_frame = int(video_player.stream_position * 60)  # Assuming 60fps
	tracking_data["keyframes"][current_frame] = tracking_data["point"]

	match tracking_data["mode"]:
		"Track Object":
			_track_object()
		"Track Face":
			_track_face()
		"Track Motion":
			_track_motion()

func _track_object():
	# Here you would implement object tracking
	# This could use OpenCV or a similar computer vision library
	# For now, we'll use a simple linear interpolation between keyframes
	pass

func _track_face():
	# Here you would implement face tracking
	# This could use a face detection library
	pass

func _track_motion():
	# Here you would implement motion tracking
	# This could use optical flow algorithms
	pass

func _update_tracking():
	var current_frame = int(video_player.stream_position * 60)

	# Simple linear interpolation between keyframes
	var prev_frame = current_frame
	var next_frame = current_frame

	for frame in tracking_data["keyframes"].keys():
		if frame <= current_frame and frame > prev_frame:
			prev_frame = frame
		if frame > current_frame and (frame < next_frame or next_frame == current_frame):
			next_frame = frame

	if prev_frame != next_frame:
		var t = float(current_frame - prev_frame) / float(next_frame - prev_frame)
		var prev_pos = tracking_data["keyframes"][prev_frame]
		var next_pos = tracking_data["keyframes"][next_frame]
		tracking_data["point"] = prev_pos.lerp(next_pos, t)

		tracking_point.position = tracking_data["point"]
		tracking_box.position = tracking_data["point"] - tracking_data["box_size"] / 2

func _update_subtitle_position():
	if tracking_data["mode"] == "Static":
		return

	var target_pos = tracking_data["point"] + tracking_data["offset"]

	# Apply perspective and scaling if enabled
	if tracking_data["perspective"]:
		# Here you would adjust the position based on perspective transform
		pass

	if tracking_data["scale"]:
		# Here you would adjust the scale based on box size
		var scale_factor = tracking_data["box_size"].length() / 100.0
		subtitles_label.scale = Vector2.ONE * scale_factor

	subtitles_overlay.position = target_pos

func _update_subtitle_effects():
	if tracking_data["motion_blur"]:
		# Here you would apply motion blur effect based on tracking velocity
		pass

	if tracking_data["perspective"]:
		# Here you would apply perspective transform
		pass

	if tracking_data["scale"]:
		# Update scale based on tracking box size
		var scale_factor = tracking_data["box_size"].length() / 100.0
		subtitles_label.scale = Vector2.ONE * scale_factor

func _update_tracking_ui():
	var is_static = tracking_data["mode"] == "Static"
	select_point_button.disabled = is_static
	start_tracking_button.disabled = is_static
	clear_tracking_button.disabled = is_static

func _add_layer(name: String):
	var layer = SubtitleLayer.new(name)
	layers.append(layer)
	_refresh_layer_list()
	layer_list.select(layers.size() - 1)
	_on_layer_selected(layers.size() - 1)
	_record_action("add_layer", layers.size() - 1, {}, {"layer": layer})

func _on_add_layer_pressed():
	_add_layer("New Layer " + str(layers.size() + 1))
func _refresh_layer_list():
	if not layer_list:
		return

	layer_list.clear()
	for i in range(layers.size()):
		var layer = layers[i]
		layer_list.add_item(layer.name, visible_icon if layer.visible else hidden_icon)

	if current_layer_index >= 0:
		layer_list.select(current_layer_index)
		layer_list.ensure_current_is_visible()

func _on_layer_selected(index: int):
	current_layer_index = index
	if index >= 0 and index < layers.size():
		var layer = layers[index]
		# Load layer settings
		font_settings = layer.font_settings.duplicate()
		tracking_data = layer.tracking_data.duplicate()
		_apply_font_settings()
		_update_tracking_ui()
		_refresh_subtitle_list()

func _on_layer_activated(index: int):
	var click_pos = get_viewport().get_mouse_position()
	if click_pos.x < layer_list.position.x + 32:  # Click on visibility icon
		_update_layer_visibility(index, !layers[index].visible)
	else:
		layer_options.position = click_pos
		layer_options.popup()

func _on_layer_option_selected(id: int):
	match id:
		0:  # Rename
			if current_layer_index >= 0:
				rename_dialog.popup_centered()
				rename_input.text = layers[current_layer_index].name
				rename_input.select_all()
		1:  # Duplicate
			if current_layer_index >= 0:
				var new_layer = layers[current_layer_index].duplicate()
				layers.insert(current_layer_index + 1, new_layer)
				_refresh_layer_list()
		2:  # Merge Down
			if current_layer_index > 0:
				_merge_layers(current_layer_index, current_layer_index - 1)
		3:  # Delete
			if current_layer_index >= 0:
				layers.remove_at(current_layer_index)
				current_layer_index = -1
				_refresh_layer_list()

func _merge_layers(top_index: int, bottom_index: int):
	var top_layer = layers[top_index]
	var bottom_layer = layers[bottom_index]

	# Merge subtitles
	for subtitle in top_layer.subtitles:
		bottom_layer.subtitles.append(subtitle.duplicate(true))

	# Remove top layer
	layers.remove_at(top_index)
	current_layer_index = bottom_index
	_refresh_layer_list()

func _on_rename_confirmed():
	if current_layer_index >= 0:
		layers[current_layer_index].name = rename_input.text
		_refresh_layer_list()
	rename_dialog.hide()

func _on_rename_canceled():
	rename_dialog.hide()


func _on_add_video_pressed():
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.mp4 ; Video Files"]
	file_dialog.file_selected.connect(_on_video_file_selected)
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2(800, 600))

func _on_video_file_selected(path: String):
	var layer = VideoLayer.new("Video " + str(video_layers.size() + 1), path)
	_add_video_layer(layer)

func _add_video_layer(layer: VideoLayer):
	# Create video player for layer
	var video_player = VideoStreamPlayer.new()
	video_player.stream = load(layer.video_path)
	video_player.expand = true
	video_player.size = size
	video_player.modulate.a = layer.opacity

	# Add to scene
	video_layers_container.add_child(video_player)
	layer.video_player = video_player

	# Add to layers
	video_layers.append(layer)
	_refresh_video_layers()

func _on_add_mask_pressed():
	OS.alert("Mask layer functionality coming soon!")

func _refresh_video_layers():
	# Update the video layer list UI
	if video_layers_container:
		for child in video_layers_container.get_children():
			if child.has_method("queue_free"):
				child.queue_free()

		# Re-add all layers
		for layer in video_layers:
			if layer.video_player:
				video_layers_container.add_child(layer.video_player)
	mask_canvas.show()

func _on_blend_mode_selected(id: int):
	if current_layer_index < 0:
		return

	var layer = video_layers[current_layer_index]
	var old_mode = layer.blend_mode
	layer.blend_mode = blend_mode_menu.get_item_text(id)
	_apply_blend_mode(layer)

	_record_action("change_blend_mode", current_layer_index,
		{"blend_mode": old_mode},
		{"blend_mode": layer.blend_mode})

func _apply_blend_mode(layer: VideoLayer):
	match layer.blend_mode:
		"Normal":
			layer.video_player.material = null
		"Multiply":
			var material = ShaderMaterial.new()
			material.shader = preload("res://shaders/multiply.gdshader")
			layer.video_player.material = material
		"Screen":
			var material = ShaderMaterial.new()
			material.shader = preload("res://shaders/screen.gdshader")
			layer.video_player.material = material
		"Overlay":
			var material = ShaderMaterial.new()
			material.shader = preload("res://shaders/overlay.gdshader")
			layer.video_player.material = material
		"Add":
			var material = ShaderMaterial.new()
			material.shader = preload("res://shaders/add.gdshader")
			layer.video_player.material = material
		"Subtract":
			var material = ShaderMaterial.new()
			material.shader = preload("res://shaders/subtract.gdshader")
			layer.video_player.material = material
		"Alpha":
			var material = ShaderMaterial.new()
			material.shader = preload("res://shaders/alpha.gdshader")
			layer.video_player.material = material
		"Draw":
			var material = ShaderMaterial.new()
			material.shader = preload("res://shaders/draw_mask.gdshader")
			# Create mask texture from drawn points
			var mask_image = Image.new()
			mask_image.create(1920, 1080, false, Image.FORMAT_RGBA8)
			for point in mask_draw_points:
				mask_image.set_pixel(point.x, point.y, Color.WHITE)
			var mask_texture = ImageTexture.new()
			mask_texture.create_from_image(mask_image)
			material.set_shader_parameter("mask_texture", mask_texture)

	material.set_shader_parameter("feather", layer.mask_settings["feather"])
	layer.video_player.material = material

func _on_opacity_changed(value: float):
	if current_layer_index < 0:
		return

	var layer = video_layers[current_layer_index]
	layer.opacity = value
	layer.video_player.modulate.a = value

func _on_scale_changed(_value: float):
	if current_layer_index < 0:
		return

	var layer = video_layers[current_layer_index]
	var scale = Vector2(scale_x.value, scale_y.value)
	if link_scale.button_pressed:
		scale.y = scale.x
		scale_y.value = scale.x

	layer.transform.x = Vector2(scale.x, 0)
	layer.transform.y = Vector2(0, scale.y)
	layer.video_player.transform = layer.transform

func _on_link_scale_toggled(enabled: bool):
	if enabled and current_layer_index >= 0:
		scale_y.value = scale_x.value

func _on_rotation_changed(value: float):
	if current_layer_index < 0:
		return

	var layer = video_layers[current_layer_index]
	layer.transform = layer.transform.rotated(deg_to_rad(value))
	layer.video_player.transform = layer.transform

func _on_mask_type_changed(index: int):
	if current_layer_index < 0:
		return

	var layer = video_layers[current_layer_index]
	layer.mask_settings["type"] = mask_type.get_item_text(index)
	_apply_mask(layer)

func _on_key_color_changed(color: Color):
	if current_layer_index < 0:
		return

	var layer = video_layers[current_layer_index]
	layer.mask_settings["key_color"] = color
	_apply_mask(layer)

func _on_tolerance_changed(value: float):
	if current_layer_index < 0:
		return

	var layer = video_layers[current_layer_index]
	layer.mask_settings["tolerance"] = value
	_apply_mask(layer)

func _on_feather_changed(value: float):
	if current_layer_index < 0:
		return

	var layer = video_layers[current_layer_index]
	layer.mask_settings["feather"] = value
	_apply_mask(layer)

func _apply_mask(layer: VideoLayer):
	var material = ShaderMaterial.new()

	match layer.mask_settings["type"]:
		"Alpha":
			material.shader = preload("res://shaders/alpha_mask.gdshader")
		"Luminance":
			material.shader = preload("res://shaders/luminance_mask.gdshader")
		"Color Key":
			material.shader = preload("res://shaders/color_key.gdshader")
			material.set_shader_parameter("key_color", layer.mask_settings["key_color"])
			material.set_shader_parameter("tolerance", layer.mask_settings["tolerance"])
		"Draw":
			material.shader = preload("res://shaders/draw_mask.gdshader")
			# Create mask texture from drawn points
			var mask_image = Image.new()
			mask_image.create(1920, 1080, false, Image.FORMAT_RGBA8)
			for point in mask_draw_points:
				mask_image.set_pixel(point.x, point.y, Color.WHITE)
			var mask_texture = ImageTexture.new()
			mask_texture.create_from_image(mask_image)
			material.set_shader_parameter("mask_texture", mask_texture)

	material.set_shader_parameter("feather", layer.mask_settings["feather"])
	layer.video_player.material = material

func _draw():
	if is_drawing_mask:
		for i in range(1, mask_draw_points.size()):
			draw_line(mask_draw_points[i-1], mask_draw_points[i], Color.WHITE, 2.0)

func _on_camera_button_pressed():
	if !is_camera_active:
		_start_camera()
	else:
		_stop_camera()

func _start_camera():
	if !camera_driver:
		camera_driver = CameraDriver.new()

	var devices = camera_driver.get_device_list()
	if devices.size() > 0:
		# Try different devices until one works
		for device in devices:
			if _debug:
				print("Trying camera device: ", device)

			# Create a camera stream
			var camera_stream = CameraStream.new()
			if camera_stream.set_device(device):
				camera_stream.start()
				if camera_preview:
					camera_preview.show()
				if camera_button:
					camera_button.modulate = Color(0, 1, 0, 1)

				video_player.stream = camera_stream
				video_player.paused = false
				is_playing = true
				is_camera_active = true
				return
			else:
				camera_stream.free()

		push_error("No working camera found")
	else:
		push_error("No camera devices found")

func _stop_camera():
	if camera_driver:
		camera_driver.stop()
		if camera_preview:
			camera_preview.hide()
			camera_preview.texture = null
		is_camera_active = false
		if camera_button:
			camera_button.modulate = Color.WHITE
		if video_player and video_player.stream is CameraStream:
			video_player.stream.stop()
			video_player.stream = null
		set_process(false)

func _exit_tree():
	if camera_driver:
		camera_driver.stop()

func _update_layer_visibility(index: int, visible: bool):
	if index >= 0 and index < layers.size():
		layers[index].visible = visible
		var item = layer_list.get_item(index)
		layer_list.set_item_text(index, layers[index].name)
		layer_list.set_item_icon(index, visible_icon if visible else hidden_icon)
		_update_subtitles()

func _create_visibility_icons():
	# Create visible icon
	var visible_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	visible_img.fill(Color(0, 0, 0, 0))
	var visible_font = SystemFont.new()
	var visible_text = "👁"
	var visible_size = visible_font.get_string_size(visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	visible_font.draw_string(visible_img, Vector2((16 - visible_size.x) / 2, 13), visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	visible_icon = ImageTexture.create_from_image(visible_img)

	# Create hidden icon
	var hidden_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	hidden_img.fill(Color(0, 0, 0, 0))
	var hidden_font = SystemFont.new()
	var hidden_text = "🚫"
	var hidden_size = hidden_font.get_string_size(hidden_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	hidden_font.draw_string(hidden_img, Vector2((16 - hidden_size.x) / 2, 13), hidden_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	hidden_icon = ImageTexture.create_from_image(hidden_img)


func _on_undo_pressed():
	if not undo_stack.is_empty():
		var action = undo_stack.pop_back()
		_apply_undo_action(action)
		redo_stack.push_back(action)
		_update_undo_redo_buttons()

func _on_redo_pressed():
	if not redo_stack.is_empty():
		var action = redo_stack.pop_back()
		_apply_redo_action(action)
		undo_stack.push_back(action)
		_update_undo_redo_buttons()

func _apply_undo_action(action: UndoAction):
	match action.action_type:
		"edit":
			layers[action.layer_index].subtitles = action.old_state["subtitles"].duplicate(true)
			layers[action.layer_index].font_settings = action.old_state["font_settings"].duplicate(true)
			layers[action.layer_index].tracking_data = action.old_state["tracking_data"].duplicate(true)
		"visibility":
			layers[action.layer_index].visible = action.old_state["visible"]
		"rename":
			layers[action.layer_index].name = action.old_state["name"]
		"delete":
			layers.insert(action.layer_index, action.old_state["layer"])
		"add":
			layers.remove_at(action.layer_index)
	_refresh_layer_list()
	_apply_font_settings()

func _apply_redo_action(action: UndoAction):
	match action.action_type:
		"edit":
			layers[action.layer_index].subtitles = action.new_state["subtitles"].duplicate(true)
			layers[action.layer_index].font_settings = action.new_state["font_settings"].duplicate(true)
			layers[action.layer_index].tracking_data = action.new_state["tracking_data"].duplicate(true)
		"visibility":
			layers[action.layer_index].visible = action.new_state["visible"]
		"rename":
			layers[action.layer_index].name = action.new_state["name"]
		"delete":
			layers.remove_at(action.layer_index)
		"add":
			layers.insert(action.layer_index, action.new_state["layer"])
	_refresh_layer_list()
	_apply_font_settings()

func _update_undo_redo_buttons():
	if undo_button:
		undo_button.disabled = undo_stack.is_empty()
	if redo_button:
		redo_button.disabled = redo_stack.is_empty()

func _record_action(action_type: String, layer_index: int, old_state: Dictionary, new_state: Dictionary):
	var action = UndoAction.new(action_type, layer_index, old_state, new_state)
	undo_stack.append(action)
	redo_stack.clear()
	_update_undo_redo_buttons()
