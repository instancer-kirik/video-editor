extends Control

signal media_imported(file_path: String, media_type: String)
signal timeline_updated(media_list: Array)

@onready var import_video_button: Button = $VBoxContainer/ImportSection/ButtonsContainer/ImportVideoButton
@onready var import_audio_button: Button = $VBoxContainer/ImportSection/ButtonsContainer/ImportAudioButton
@onready var import_image_button: Button = $VBoxContainer/ImportSection/ButtonsContainer/ImportImageButton
@onready var drop_zone: Panel = $VBoxContainer/ImportSection/DropZone
@onready var drop_label: Label = $VBoxContainer/ImportSection/DropZone/DropLabel
@onready var media_items: VBoxContainer = $VBoxContainer/MediaList/ScrollContainer/MediaItems
@onready var timeline_container: Panel = $VBoxContainer/TimelineSection/TimelineContainer
@onready var timeline_drop_zone: Label = $VBoxContainer/TimelineSection/TimelineContainer/TimelineDropZone
@onready var clear_button: Button = $VBoxContainer/ControlsSection/ClearButton
@onready var export_button: Button = $VBoxContainer/ControlsSection/ExportButton
@onready var close_button: Button = $VBoxContainer/ControlsSection/CloseButton
@onready var file_dialog: FileDialog = $FileDialog

var imported_media: Array = []
var timeline_items: Array = []
var current_import_type: String = ""
var drag_preview: Control = null

# Media item class for organizing imported files
class MediaItem:
	var file_path: String
	var file_name: String
	var media_type: String  # "video", "audio", "image"
	var duration: float = 0.0
	var thumbnail: Texture2D = null
	var metadata: Dictionary = {}

	func _init(path: String, type: String):
		file_path = path
		file_name = path.get_file()
		media_type = type
		_load_metadata()

	func _load_metadata():
		match media_type:
			"video":
				# Try to load video metadata
				var video_stream = load(file_path) as VideoStream
				if video_stream:
					duration = video_stream.get_length()
					metadata["resolution"] = "Unknown"
					metadata["codec"] = "Unknown"
			"audio":
				# Try to load audio metadata
				var audio_stream = load(file_path) as AudioStream
				if audio_stream:
					duration = audio_stream.get_length()
					metadata["sample_rate"] = "Unknown"
					metadata["channels"] = "Unknown"
			"image":
				# Load image metadata
				var image = Image.new()
				var error = image.load(file_path)
				if error == OK:
					metadata["resolution"] = str(image.get_width()) + "x" + str(image.get_height())
					metadata["format"] = file_path.get_extension().to_upper()

func _ready():
	# Set up drag and drop
	drop_zone.set_accept_drops(true)
	timeline_container.set_accept_drops(true)

	# Configure file dialog
	file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_MOVIES)

	print("[VideoImporter] Video importer ready")

func _can_drop_data(position: Vector2, data) -> bool:
	if data is Dictionary and data.has("files"):
		var files = data["files"] as PackedStringArray
		for file in files:
			if _is_supported_file(file):
				return true
	return false

func _drop_data(position: Vector2, data):
	if data is Dictionary and data.has("files"):
		var files = data["files"] as PackedStringArray
		for file in files:
			if _is_supported_file(file):
				_import_file(file)

func _is_supported_file(file_path: String) -> bool:
	var ext = file_path.get_extension().to_lower()

	# Video formats
	if ext in ["mp4", "avi", "mov", "mkv", "webm", "ogv"]:
		return true

	# Audio formats
	if ext in ["mp3", "wav", "ogg", "flac", "m4a"]:
		return true

	# Image formats
	if ext in ["png", "jpg", "jpeg", "bmp", "tga", "webp"]:
		return true

	return false

func _get_media_type(file_path: String) -> String:
	var ext = file_path.get_extension().to_lower()

	if ext in ["mp4", "avi", "mov", "mkv", "webm", "ogv"]:
		return "video"
	elif ext in ["mp3", "wav", "ogg", "flac", "m4a"]:
		return "audio"
	elif ext in ["png", "jpg", "jpeg", "bmp", "tga", "webp"]:
		return "image"

	return "unknown"

func _import_file(file_path: String):
	var media_type = _get_media_type(file_path)
	if media_type == "unknown":
		push_error("Unsupported file type: " + file_path)
		return

	# Check if already imported
	for item in imported_media:
		if item.file_path == file_path:
			print("[VideoImporter] File already imported: " + file_path)
			return

	# Create media item
	var media_item = MediaItem.new(file_path, media_type)
	imported_media.append(media_item)

	# Create UI item
	_create_media_item_ui(media_item)

	print("[VideoImporter] Imported " + media_type + ": " + file_path)
	emit_signal("media_imported", file_path, media_type)

func _create_media_item_ui(media_item: MediaItem):
	var item_container = HBoxContainer.new()
	item_container.set_custom_minimum_size(Vector2(0, 60))

	# Icon based on media type
	var icon = TextureRect.new()
	icon.set_custom_minimum_size(Vector2(48, 48))
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Set icon based on media type
	match media_item.media_type:
		"video":
			icon.modulate = Color(0.2, 0.8, 0.2)  # Green tint for video
		"audio":
			icon.modulate = Color(0.2, 0.2, 0.8)  # Blue tint for audio
		"image":
			icon.modulate = Color(0.8, 0.8, 0.2)  # Yellow tint for images

	item_container.add_child(icon)

	# Info section
	var info_container = VBoxContainer.new()
	info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# File name
	var name_label = Label.new()
	name_label.text = media_item.file_name
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_container.add_child(name_label)

	# Metadata
	var metadata_label = Label.new()
	var metadata_text = media_item.media_type.capitalize()
	if media_item.duration > 0:
		metadata_text += " • " + _format_duration(media_item.duration)
	if media_item.metadata.has("resolution"):
		metadata_text += " • " + str(media_item.metadata["resolution"])

	metadata_label.text = metadata_text
	metadata_label.add_theme_font_size_override("font_size", 12)
	metadata_label.modulate = Color(0.8, 0.8, 0.8)
	info_container.add_child(metadata_label)

	item_container.add_child(info_container)

	# Action buttons
	var button_container = HBoxContainer.new()

	# Add to timeline button
	var add_button = Button.new()
	add_button.text = "Add to Timeline"
	add_button.pressed.connect(_on_add_to_timeline.bind(media_item))
	button_container.add_child(add_button)

	# Remove button
	var remove_button = Button.new()
	remove_button.text = "Remove"
	remove_button.pressed.connect(_on_remove_media.bind(media_item, item_container))
	button_container.add_child(remove_button)

	item_container.add_child(button_container)

	# Add separator
	var separator = HSeparator.new()
	media_items.add_child(separator)
	media_items.add_child(item_container)

func _format_duration(seconds: float) -> String:
	if seconds <= 0:
		return "0s"

	var minutes = int(seconds / 60)
	var secs = int(seconds) % 60

	if minutes > 0:
		return str(minutes) + "m " + str(secs) + "s"
	else:
		return str(secs) + "s"

func _on_add_to_timeline(media_item: MediaItem):
	# Check if already in timeline
	for item in timeline_items:
		if item.file_path == media_item.file_path:
			print("[VideoImporter] Item already in timeline: " + media_item.file_name)
			return

	timeline_items.append(media_item)
	_update_timeline_ui()

	print("[VideoImporter] Added to timeline: " + media_item.file_name)
	emit_signal("timeline_updated", timeline_items)

func _on_remove_media(media_item: MediaItem, ui_container: Control):
	# Remove from imported media
	imported_media.erase(media_item)

	# Remove from timeline if present
	timeline_items.erase(media_item)

	# Remove UI elements
	ui_container.queue_free()

	# Update timeline
	_update_timeline_ui()

	print("[VideoImporter] Removed media: " + media_item.file_name)

func _update_timeline_ui():
	if timeline_items.is_empty():
		timeline_drop_zone.text = "Drop media files here to add to timeline"
		timeline_drop_zone.show()
	else:
		timeline_drop_zone.hide()
		# Here you would create timeline visualization
		# For now, just show a simple list
		var timeline_text = "Timeline (" + str(timeline_items.size()) + " items):\n"
		for i in range(timeline_items.size()):
			var item = timeline_items[i]
			timeline_text += str(i + 1) + ". " + item.file_name + " (" + item.media_type + ")\n"

		timeline_drop_zone.text = timeline_text
		timeline_drop_zone.show()

# Button handlers
func _on_import_video_pressed():
	current_import_type = "video"
	file_dialog.clear_filters()
	file_dialog.add_filter("*.mp4, *.avi, *.mov, *.mkv, *.webm, *.ogv", "Video Files")
	file_dialog.popup_centered()

func _on_import_audio_pressed():
	current_import_type = "audio"
	file_dialog.clear_filters()
	file_dialog.add_filter("*.mp3, *.wav, *.ogg, *.flac, *.m4a", "Audio Files")
	file_dialog.popup_centered()

func _on_import_image_pressed():
	current_import_type = "image"
	file_dialog.clear_filters()
	file_dialog.add_filter("*.png, *.jpg, *.jpeg, *.bmp, *.tga, *.webp", "Image Files")
	file_dialog.popup_centered()

func _on_files_selected(files: PackedStringArray):
	for file in files:
		_import_file(file)

func _on_drop_zone_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Show generic file dialog
			file_dialog.clear_filters()
			file_dialog.add_filter("*.mp4, *.avi, *.mov, *.mkv, *.webm, *.ogv", "Video Files")
			file_dialog.add_filter("*.mp3, *.wav, *.ogg, *.flac, *.m4a", "Audio Files")
			file_dialog.add_filter("*.png, *.jpg, *.jpeg, *.bmp, *.tga, *.webp", "Image Files")
			file_dialog.popup_centered()

func _on_timeline_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Allow clicking to add first available media to timeline
			if not imported_media.is_empty() and timeline_items.is_empty():
				_on_add_to_timeline(imported_media[0])

func _on_clear_pressed():
	# Clear all data
	imported_media.clear()
	timeline_items.clear()

	# Clear UI
	for child in media_items.get_children():
		child.queue_free()

	_update_timeline_ui()

	print("[VideoImporter] Cleared all media and timeline")

func _on_export_pressed():
	if timeline_items.is_empty():
		OS.alert("No media in timeline to export!")
		return

	# For now, just show a message about export functionality
	var export_info = "Export would create a video from timeline items:\n\n"
	for i in range(timeline_items.size()):
		var item = timeline_items[i]
		export_info += str(i + 1) + ". " + item.file_name + " (" + item.media_type + ")\n"

	export_info += "\nThis feature requires video encoding implementation."
	OS.alert(export_info)

func _on_close_pressed():
	hide()

# Public API for external access
func get_imported_media() -> Array:
	return imported_media

func get_timeline_items() -> Array:
	return timeline_items

func add_media_to_timeline(file_path: String):
	for item in imported_media:
		if item.file_path == file_path:
			_on_add_to_timeline(item)
			return

	# If not imported yet, import it first
	_import_file(file_path)

func clear_timeline():
	timeline_items.clear()
	_update_timeline_ui()

func show_importer():
	show()
	popup_centered() if has_method("popup_centered") else show()
