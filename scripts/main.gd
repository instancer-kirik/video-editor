extends Control

# Custom types
class_name MainEditor

class CameraDevice:
	var video_player: VideoStreamPlayer
	var camera_stream: CameraStream
	var active: bool = false
	var _device_path: String
	var _is_initialized: bool = false
	var _width: int = 640
	var _height: int = 480
	var _format: String = "MJPG"
	var _fps: int = 30
	var _pipeline_started: bool = false
	var _pipeline_error: String = ""

	func _init():
		video_player = VideoStreamPlayer.new()
		camera_stream = CameraStream.new()
		video_player.stream = camera_stream

		# Configure video player
		video_player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		video_player.size_flags_vertical = Control.SIZE_EXPAND_FILL
		video_player.expand = true
		video_player.visible = false # Start invisible
		video_player.process_mode = Node.PROCESS_MODE_ALWAYS

		# Connect to video player signals
		video_player.finished.connect(_on_playback_finished)

		# Connect to camera stream signals if available
		if camera_stream.has_signal("stream_started"):
			camera_stream.stream_started.connect(_on_pipeline_started)
		if camera_stream.has_signal("stream_error"):
			camera_stream.stream_error.connect(_on_pipeline_error)

	func _on_pipeline_started():
		_pipeline_started = true
		_pipeline_error = ""
		video_player.visible = true
		print("[CameraDevice] Pipeline started successfully")

	func _on_pipeline_error(error: String):
		_pipeline_error = error
		print("[CameraDevice] Pipeline error: ", error)
		set_active(false)

	func _on_playback_finished():
		if active:
			# If we're active and playback finished, try to restart
			video_player.play()

	func set_active(enabled: bool):
		if active == enabled:
			return

		active = enabled
		if enabled:
			if not _is_initialized:
				push_error("Camera stream is not initialized")
				active = false
				return

			print("[CameraDevice] Starting camera stream...")
			_pipeline_started = false
			_pipeline_error = ""

			# Start camera stream with current settings
			camera_stream.start()
			video_player.play()

			# Give the pipeline a chance to start
			var start_time = Time.get_ticks_msec()
			while not _pipeline_started and _pipeline_error.is_empty() and Time.get_ticks_msec() - start_time < 5000:
				OS.delay_msec(100)

			if not _pipeline_started:
				if _pipeline_error.is_empty():
					print("[CameraDevice] Pipeline failed to start: timeout")
				else:
					print("[CameraDevice] Pipeline failed to start: ", _pipeline_error)
				active = false
				return
		else:
			print("[CameraDevice] Stopping camera stream...")
			video_player.visible = false
			video_player.stop()

			# Important: Stop camera stream before clearing
			if camera_stream:
				camera_stream.stop()

			# Clear stream and player
			video_player.stream = null
			camera_stream = null
			_is_initialized = false
			_pipeline_started = false
			_pipeline_error = ""
			print("[CameraDevice] Camera stream stopped")

	func is_active() -> bool:
		return active and _is_initialized and camera_stream != null and video_player != null and _pipeline_started

	func get_texture() -> Texture2D:
		if not is_active():
			return null
		return camera_stream.get_texture()

	func set_device(path: String, width: int = 640, height: int = 480, format: String = "MJPG", fps: int = 30):
		_device_path = path
		_width = width
		_height = height
		_format = format
		_fps = fps

		# Update video player size
		video_player.custom_minimum_size = Vector2(width, height)

		# Set up camera stream
		if camera_stream == null:
			camera_stream = CameraStream.new()
			video_player.stream = camera_stream
			if camera_stream.has_signal("stream_started"):
				camera_stream.stream_started.connect(_on_pipeline_started)
			if camera_stream.has_signal("stream_error"):
				camera_stream.stream_error.connect(_on_pipeline_error)

		print("[CameraDevice] Setting up device: ", path, " with resolution: ", width, "x", height)
		camera_stream.set_device(path, width, height)
		_is_initialized = true

	func start_recording(output_path: String) -> bool:
		if not is_active():
			return false
		return camera_stream.start_recording(output_path)

@onready var video_player = $VideoPlayer
@onready var timeline_editor = $TimelineEditor
@onready var camera_preview = $CameraPreview

# Editor panels
@onready var editor_panels = $EditorPanels
@onready var video_panel = $EditorPanels/VideoPanel
@onready var camera_panel = $EditorPanels/CameraPanel
@onready var subtitles_panel: Control = $EditorPanels/SubtitlesPanel
@onready var compositing_panel: Control = $EditorPanels/CompositingPanel
@onready var layers_panel: Control = $EditorPanels/LayersPanel
@onready var effects_panel: Control = $EditorPanels/EffectsPanel

# Video importer
var video_importer: Control = null
var video_importer_scene = preload("res://scenes/video_importer.tscn")

# Camera controls
@onready var device_selector = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/DeviceSection/DeviceSelector
@onready var resolution_selector = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/ResolutionSection/ResolutionSelector
@onready var start_button = $EditorPanels/CameraPanel/VBoxContainer/Controls/Buttons/StartButton
@onready var record_button = $EditorPanels/CameraPanel/VBoxContainer/Controls/RecordingControls/RecordButton
@onready var stop_button = $EditorPanels/CameraPanel/VBoxContainer/Controls/Buttons/StopButton
@onready var auto_focus = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/FocusSection/AutoFocus
@onready var auto_exposure = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/ExposureSection/AutoExposure
@onready var grid_check = $EditorPanels/CameraPanel/VBoxContainer/PreviewSettings/GridCheck
@onready var histogram_check = $EditorPanels/CameraPanel/VBoxContainer/PreviewSettings/HistogramCheck

var video_feed: Node
var current_mode: String = "video"
var camera_device: CameraDevice = null
var is_recording: bool = false
var v4l2_devices = []
var network_cameras = []
var _camera_starting: bool = false
var _camera_thread: Thread = null
var _camera_mutex: Mutex = null
var _camera_semaphore: Semaphore = null

func _ready():
	_camera_mutex = Mutex.new()
	_camera_semaphore = Semaphore.new()

	# Get video feed singleton
	video_feed = get_node("/root/VideoFeed")
	if video_feed:
		# Connect video feed signals
		if video_feed.has_signal("video_changed"):
			video_feed.video_changed.connect(_on_video_changed)

		# Load initial video
		if video_feed.has_method("get_current_video"):
			var initial_video = video_feed.get_current_video()
			if initial_video:
				_load_video(initial_video)

	# Connect signals between components if they exist
	if timeline_editor and video_player:
		if video_player.has_method("_on_trim_changed"):
			timeline_editor.trim_changed.connect(video_player._on_trim_changed)
		if video_player.has_method("_on_seek_position"):
			timeline_editor.seek_position.connect(video_player._on_seek_position)
		if video_player.has_method("_on_speed_changed"):
			timeline_editor.playback_speed_changed.connect(video_player._on_speed_changed)

	# Connect camera control signals
	var format_selector = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/FormatSection/FormatSelector
	var resolution_selector = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/ResolutionSection/ResolutionSelector
	var framerate_selector = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/FramerateSection/FramerateSelector

	if device_selector:
		device_selector.item_selected.connect(_on_camera_device_selected)
	if format_selector:
		format_selector.item_selected.connect(_on_format_selected)
	if resolution_selector:
		resolution_selector.item_selected.connect(_on_resolution_selected)

	# Connect camera button signals
	if start_button:
		start_button.pressed.connect(_on_camera_start)
	if stop_button:
		stop_button.pressed.connect(_on_camera_stop)
	if record_button:
		record_button.pressed.connect(_on_camera_record)

	# Show initial panel
	_update_panel_visibility()

	# Initialize camera settings
	_setup_camera_devices()

func _process(_delta):
	if camera_device and camera_device.is_active() and not _camera_starting:
		if camera_device.video_player and not camera_device.video_player.visible:
			camera_device.video_player.show()
			print("[MainEditor] Showing video player")

func _load_video(video_data):
	if not video_player:
		push_error("Video player not found")
		return

	# Load video in player
	video_player._load_video(video_data)

	# Set up timeline
	if video_player.video_player and video_player.video_player.stream and timeline_editor:
		timeline_editor.set_video_duration(video_player.video_player.stream.get_length())

func _on_video_changed(video_data):
	_load_video(video_data)

func _on_mode_changed(mode: String):
	current_mode = mode
	_update_panel_visibility()

	if mode == "camera":
		if not camera_device:
			_on_camera_start()
	else:
		if camera_device:
			_on_camera_stop()

func _update_panel_visibility():
	# Hide all panels if they exist
	if video_panel:
		video_panel.hide()
	if camera_panel:
		camera_panel.hide()
	if subtitles_panel:
		subtitles_panel.hide()
	if compositing_panel:
		compositing_panel.hide()
	if layers_panel:
		layers_panel.hide()
	if effects_panel:
		effects_panel.hide()

	# Show current panel
	match current_mode:
		"video":
			if video_panel:
				video_panel.show()
		"camera":
			if camera_panel:
				camera_panel.show()
		"subtitles":
			if subtitles_panel:
				subtitles_panel.show()
		"compositing":
			if compositing_panel:
				compositing_panel.show()
		"layers":
			if layers_panel:
				layers_panel.show()
		"effects":
			if effects_panel:
				effects_panel.show()

func _scan_v4l2_devices():
	v4l2_devices.clear()
	var dir = DirAccess.open("/dev")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.begins_with("video"):
				var device_path = "/dev/" + file_name
				v4l2_devices.append({
					"path": device_path,
					"name": "Camera " + file_name.substr(5)
				})
			file_name = dir.get_next()
		dir.list_dir_end()

func _scan_network_cameras():
	network_cameras.clear()
	# Add common IP camera ports to scan
	var ports = [554, 8080, 8081, 8082]
	# For now, add some common URLs
	network_cameras.append({
		"name": "DroidCam (Default)",
		"url": "http://127.0.0.1:4747/video"
	})
	network_cameras.append({
		"name": "IP Webcam (Default)",
		"url": "http://192.168.1.100:8080/video"
	})

func _setup_camera_devices():
	if not device_selector:
		push_error("Device selector not found")
		return

	device_selector.clear()

	# Scan for V4L2 devices
	_scan_v4l2_devices()

	# Scan for network cameras
	_scan_network_cameras()

	# Add V4L2 devices
	for device in v4l2_devices:
		device_selector.add_item(device.name, v4l2_devices.find(device))

	# Add separator if we have both types
	if v4l2_devices.size() > 0 and network_cameras.size() > 0:
		device_selector.add_separator()

	# Add network cameras
	for camera in network_cameras:
		device_selector.add_item(camera.name, v4l2_devices.size() + network_cameras.find(camera))

	# Select first device if available
	if device_selector.item_count > 0:
		device_selector.select(0)
		_on_camera_device_selected(0)

func _setup_camera_formats(device_path: String):
	var format_selector = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/FormatSection/FormatSelector
	if not format_selector:
		return

	format_selector.clear()

	# Get supported formats
	var output = []
	var exit_code = OS.execute("v4l2-ctl", ["--device=" + device_path, "--list-formats-ext"], output)
	if exit_code != 0:
		return

	var format_text = str(output)
	if format_text.contains("MJPG"):
		format_selector.add_item("MJPEG", 0)
	if format_text.contains("YUYV"):
		format_selector.add_item("YUYV", 1)

	if format_selector.item_count > 0:
		format_selector.select(0)
		_on_format_selected(0)

func _setup_camera_resolutions(device_path: String, format_id: int):
	var resolution_selector = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/ResolutionSection/ResolutionSelector
	if not resolution_selector:
		return

	resolution_selector.clear()

	# Get supported resolutions for the selected format
	var output = []
	var format_name = "MJPG" if format_id == 0 else "YUYV"
	var exit_code = OS.execute("v4l2-ctl", ["--device=" + device_path, "--list-formats-ext"], output)
	if exit_code != 0:
		return

	var format_text = str(output)
	var resolutions = []

	# Parse resolutions
	if format_text.contains("1920x1080"):
		resolutions.append(Vector2i(1920, 1080))
	if format_text.contains("1280x720"):
		resolutions.append(Vector2i(1280, 720))
	if format_text.contains("640x480"):
		resolutions.append(Vector2i(640, 480))
	if format_text.contains("320x240"):
		resolutions.append(Vector2i(320, 240))

	# Add resolutions to selector
	for res in resolutions:
		resolution_selector.add_item(str(res.x) + "x" + str(res.y))

	if resolution_selector.item_count > 0:
		resolution_selector.select(0)
		_on_resolution_selected(0)

func _setup_camera_framerates(device_path: String, format_id: int, resolution: Vector2i):
	var framerate_selector = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/FramerateSection/FramerateSelector
	if not framerate_selector:
		return

	framerate_selector.clear()

	# Get supported framerates for the selected format and resolution
	var output = []
	var format_name = "MJPG" if format_id == 0 else "YUYV"
	var exit_code = OS.execute("v4l2-ctl", ["--device=" + device_path, "--list-formats-ext"], output)
	if exit_code != 0:
		return

	var format_text = str(output)
	var framerates = []

	# Parse framerates
	if format_text.contains("30.000 fps"):
		framerates.append(30)
	if format_text.contains("15.000 fps"):
		framerates.append(15)
	if format_text.contains("10.000 fps"):
		framerates.append(10)
	if format_text.contains("5.000 fps"):
		framerates.append(5)

	# Add framerates to selector
	for fps in framerates:
		framerate_selector.add_item(str(fps) + " fps")

	if framerate_selector.item_count > 0:
		framerate_selector.select(0)

func _setup_camera_controls(device_path: String):
	# Get camera controls
	var output = []
	var exit_code = OS.execute("v4l2-ctl", ["--device=" + device_path, "--list-ctrls"], output)
	if exit_code != 0:
		return

	var controls_text = str(output)

	# Setup exposure controls
	var auto_exposure = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/ExposureSection/AutoExposure
	var exposure_slider = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/ExposureSection/ExposureSlider

	if controls_text.contains("exposure_auto"):
		auto_exposure.visible = true
		auto_exposure.pressed.connect(_on_auto_exposure_toggled)
	else:
		auto_exposure.visible = false

	if controls_text.contains("exposure_absolute"):
		exposure_slider.visible = true
		exposure_slider.value_changed.connect(_on_exposure_changed)
	else:
		exposure_slider.visible = false

	# Setup focus controls
	var auto_focus = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/FocusSection/AutoFocus
	var focus_slider = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/FocusSection/FocusSlider

	if controls_text.contains("focus_auto"):
		auto_focus.visible = true
		auto_focus.pressed.connect(_on_auto_focus_toggled)
	else:
		auto_focus.visible = false

	if controls_text.contains("focus_absolute"):
		focus_slider.visible = true
		focus_slider.value_changed.connect(_on_focus_changed)
	else:
		focus_slider.visible = false

	# Setup white balance controls
	var auto_wb = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/WhiteBalanceSection/AutoWB
	var temp_slider = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/WhiteBalanceSection/TempSlider

	if controls_text.contains("white_balance_temperature_auto"):
		auto_wb.visible = true
		auto_wb.pressed.connect(_on_auto_wb_toggled)
	else:
		auto_wb.visible = false

	if controls_text.contains("white_balance_temperature"):
		temp_slider.visible = true
		temp_slider.value_changed.connect(_on_wb_temp_changed)
	else:
		temp_slider.visible = false

func _on_camera_device_selected(index: int):
	if camera_device:
		camera_device.set_active(false)
		camera_device = null

	if index >= 0:
		var device_path = ""
		if index < v4l2_devices.size():
			device_path = v4l2_devices[index].path
		else:
			var network_index = index - v4l2_devices.size()
			if network_index < network_cameras.size():
				device_path = network_cameras[network_index].url

		if device_path:
			_setup_camera_formats(device_path)
			_setup_camera_controls(device_path)

func _on_format_selected(index: int):
	var device_selector = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/DeviceSection/DeviceSelector
	if device_selector and device_selector.selected >= 0:
		var device_path = ""
		if device_selector.selected < v4l2_devices.size():
			device_path = v4l2_devices[device_selector.selected].path

		if device_path:
			_setup_camera_resolutions(device_path, index)

func _on_resolution_selected(index: int):
	var device_selector = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/DeviceSection/DeviceSelector
	var format_selector = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/FormatSection/FormatSelector
	var resolution_selector = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/ResolutionSection/ResolutionSelector

	if device_selector and format_selector and resolution_selector:
		if device_selector.selected >= 0 and format_selector.selected >= 0:
			var device_path = ""
			if device_selector.selected < v4l2_devices.size():
				device_path = v4l2_devices[device_selector.selected].path

			if device_path:
				var res_text = resolution_selector.get_item_text(index)
				var res_parts = res_text.split("x")
				if res_parts.size() == 2:
					var resolution = Vector2i(res_parts[0].to_int(), res_parts[1].to_int())
					_setup_camera_framerates(device_path, format_selector.selected, resolution)

func _on_auto_exposure_toggled(enabled: bool):
	if not camera_device:
		return

	var output = []
	OS.execute("v4l2-ctl", ["--device=" + camera_device._device_path, "--set-ctrl=exposure_auto=" + ("3" if enabled else "1")], output)

	var exposure_slider = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/ExposureSection/ExposureSlider
	if exposure_slider:
		exposure_slider.editable = not enabled

func _on_exposure_changed(value: float):
	if not camera_device:
		return

	var output = []
	OS.execute("v4l2-ctl", ["--device=" + camera_device._device_path, "--set-ctrl=exposure_absolute=" + str(value)], output)

func _on_auto_focus_toggled(enabled: bool):
	if not camera_device:
		return

	var output = []
	OS.execute("v4l2-ctl", ["--device=" + camera_device._device_path, "--set-ctrl=focus_auto=" + ("1" if enabled else "0")], output)

	var focus_slider = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/FocusSection/FocusSlider
	if focus_slider:
		focus_slider.editable = not enabled

func _on_focus_changed(value: float):
	if not camera_device:
		return

	var output = []
	OS.execute("v4l2-ctl", ["--device=" + camera_device._device_path, "--set-ctrl=focus_absolute=" + str(value)], output)

func _on_auto_wb_toggled(enabled: bool):
	if not camera_device:
		return

	var output = []
	OS.execute("v4l2-ctl", ["--device=" + camera_device._device_path, "--set-ctrl=white_balance_temperature_auto=" + ("1" if enabled else "0")], output)

	var temp_slider = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/WhiteBalanceSection/TempSlider
	if temp_slider:
		temp_slider.editable = not enabled

func _on_wb_temp_changed(value: float):
	if not camera_device:
		return

	var output = []
	OS.execute("v4l2-ctl", ["--device=" + camera_device._device_path, "--set-ctrl=white_balance_temperature=" + str(value)], output)

func _on_camera_start():
	print("[MainEditor] Starting camera...")

	# Disable buttons immediately
	var start_button = $EditorPanels/CameraPanel/VBoxContainer/Controls/Buttons/StartButton
	var stop_button = $EditorPanels/CameraPanel/VBoxContainer/Controls/Buttons/StopButton
	var record_button = $EditorPanels/CameraPanel/VBoxContainer/Controls/RecordingControls/RecordButton

	if start_button and stop_button and record_button:
		start_button.disabled = true
		stop_button.disabled = true
		record_button.disabled = true

	# Gather all UI values before starting thread
	var device_selector = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/DeviceSection/DeviceSelector
	var format_selector = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/FormatSection/FormatSelector
	var resolution_selector = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/ResolutionSection/ResolutionSelector
	var framerate_selector = $EditorPanels/CameraPanel/VBoxContainer/ScrollContainer/Settings/FramerateSection/FramerateSelector

	if not device_selector or not format_selector or not resolution_selector or not framerate_selector:
		push_error("Camera controls not found")
		_finish_camera_start(false)
		return

	# Get device path
	var device_path = ""
	var device_index = device_selector.selected
	if device_index >= 0:
		if device_index < v4l2_devices.size():
			device_path = v4l2_devices[device_index].path
		else:
			var network_index = device_index - v4l2_devices.size()
			if network_index < network_cameras.size():
				device_path = network_cameras[network_index].url

	if device_path.is_empty():
		push_error("No camera device selected")
		_finish_camera_start(false)
		return

	# Get format
	var format_id = format_selector.get_selected_id()
	var format_name = "MJPG" if format_id == 0 else "YUYV"

	# Get resolution
	var width = 640
	var height = 480
	if resolution_selector.selected >= 0:
		var res_text = resolution_selector.get_item_text(resolution_selector.selected)
		var res_parts = res_text.split("x")
		if res_parts.size() == 2:
			width = res_parts[0].to_int()
			height = res_parts[1].to_int()

	# Get framerate
	var fps = 30
	if framerate_selector.selected >= 0:
		var fps_text = framerate_selector.get_item_text(framerate_selector.selected)
		fps = fps_text.split(" ")[0].to_int()

	# Create thread arguments
	var thread_args = {
		"device_path": device_path,
		"format": format_name,
		"width": width,
		"height": height,
		"fps": fps
	}

	# Start camera in thread
	if _camera_thread != null:
		_camera_thread.wait_to_finish()
	_camera_thread = Thread.new()
	_camera_thread.start(_camera_start_thread.bind(thread_args))

func _camera_start_thread(args: Dictionary):
	_camera_starting = true

	print("[MainEditor] Using device: ", args.device_path)
	print("[MainEditor] Selected format: ", args.format)
	print("[MainEditor] Selected resolution: ", args.width, "x", args.height)
	print("[MainEditor] Selected framerate: ", args.fps)

	# Create camera device in main thread
	call_deferred("_create_camera_device", args)
	_camera_semaphore.wait()

	if not camera_device:
		print("[MainEditor] Failed to create camera device")
		call_deferred("_finish_camera_start", false)
		return

	# Start camera with a timeout
	var start_time = Time.get_ticks_msec()
	var timeout = 5000  # 5 second timeout

	camera_device.set_active(true)

	while Time.get_ticks_msec() - start_time < timeout:
		if camera_device and camera_device.is_active():
			print("[MainEditor] Camera activated successfully")
			call_deferred("_finish_camera_start", true)
			return
		OS.delay_msec(100)  # Check every 100ms

	print("[MainEditor] Camera activation timed out")
	call_deferred("_finish_camera_start", false)

func _create_camera_device(args: Dictionary):
	_camera_mutex.lock()

	# Clean up existing camera if any
	if camera_device:
		if camera_device.video_player and camera_device.video_player.get_parent():
			camera_device.video_player.get_parent().remove_child(camera_device.video_player)
		camera_device.set_active(false)
		camera_device = null

	# Create new camera device
	var new_camera = CameraDevice.new()

	# Configure video player layout
	new_camera.video_player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_camera.video_player.size_flags_vertical = Control.SIZE_EXPAND_FILL
	new_camera.video_player.custom_minimum_size = Vector2(args.width, args.height)
	new_camera.video_player.expand = true
	new_camera.video_player.process_mode = Node.PROCESS_MODE_ALWAYS

	# Add to scene first
	add_child(new_camera.video_player)
	new_camera.video_player.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Then configure camera
	new_camera.set_device(args.device_path, args.width, args.height)
	camera_device = new_camera

	_camera_mutex.unlock()
	_camera_semaphore.post()

func _on_camera_record():
	if not camera_device:
		return

	var record_button = $EditorPanels/CameraPanel/VBoxContainer/Controls/RecordingControls/RecordButton
	var output_path = $EditorPanels/CameraPanel/VBoxContainer/Controls/RecordingControls/OutputPath

	if not record_button or not output_path:
		return

	if not camera_device.is_active():
		return

	if output_path.text.is_empty():
		push_error("Please specify an output path")
		return

	if not camera_device.start_recording(output_path.text):
		push_error("Failed to start recording")
		return

	record_button.text = "Stop Recording"

func _on_camera_stop():
	print("[MainEditor] Stopping camera...")

	# Disable buttons immediately to prevent multiple clicks
	var start_button = $EditorPanels/CameraPanel/VBoxContainer/Controls/Buttons/StartButton
	var stop_button = $EditorPanels/CameraPanel/VBoxContainer/Controls/Buttons/StopButton
	var record_button = $EditorPanels/CameraPanel/VBoxContainer/Controls/RecordingControls/RecordButton

	if start_button and stop_button and record_button:
		start_button.disabled = true
		stop_button.disabled = true
		record_button.disabled = true

	# Stop camera in a thread
	if _camera_thread != null:
		_camera_thread.wait_to_finish()
	_camera_thread = Thread.new()
	_camera_thread.start(_camera_stop_thread)

func _camera_stop_thread():
	if camera_device:
		# First hide the preview to give immediate feedback
		if camera_device.video_player:
			call_deferred("_hide_preview")
			_camera_semaphore.wait()

		# Stop with timeout
		var start_time = Time.get_ticks_msec()
		var timeout = 3000  # 3 second timeout

		_camera_mutex.lock()
		camera_device.set_active(false)

		while Time.get_ticks_msec() - start_time < timeout:
			if not camera_device.is_active():
				break
			OS.delay_msec(100)

		# Force cleanup if still active
		if camera_device.video_player:
			if camera_device.video_player.get_parent():
				call_deferred("_remove_video_player", camera_device.video_player)
				_camera_semaphore.wait()

		camera_device = null
		_camera_mutex.unlock()
		print("[MainEditor] Camera device cleaned up")

	call_deferred("_finish_camera_stop")

func _hide_preview():
	if camera_device and camera_device.video_player:
		camera_device.video_player.visible = false
	_camera_semaphore.post()

func _remove_video_player(player: VideoStreamPlayer):
	if player and player.get_parent():
		player.get_parent().remove_child(player)
		player.queue_free()
	_camera_semaphore.post()

func _finish_camera_start(success: bool):
	_camera_starting = false

	# Update UI
	var start_button = $EditorPanels/CameraPanel/VBoxContainer/Controls/Buttons/StartButton
	var stop_button = $EditorPanels/CameraPanel/VBoxContainer/Controls/Buttons/StopButton
	var record_button = $EditorPanels/CameraPanel/VBoxContainer/Controls/RecordingControls/RecordButton

	if start_button and stop_button and record_button:
		if success:
			start_button.disabled = true
			stop_button.disabled = false
			record_button.disabled = false
		else:
			start_button.disabled = false
			stop_button.disabled = true
			record_button.disabled = true

	if not success:
		# Clean up camera if start failed
		if camera_device:
			camera_device.set_active(false)
			if camera_device.video_player and camera_device.video_player.get_parent():
				camera_device.video_player.get_parent().remove_child(camera_device.video_player)
			camera_device = null

func _finish_camera_stop():
	print("[MainEditor] Finalizing camera stop...")

	# Update UI
	var start_button = $EditorPanels/CameraPanel/VBoxContainer/Controls/Buttons/StartButton
	var stop_button = $EditorPanels/CameraPanel/VBoxContainer/Controls/Buttons/StopButton
	var record_button = $EditorPanels/CameraPanel/VBoxContainer/Controls/RecordingControls/RecordButton

	if start_button and stop_button and record_button:
		start_button.disabled = false
		stop_button.disabled = true
		record_button.disabled = true
		is_recording = false
		record_button.text = "Record"

	print("[MainEditor] Camera cleanup complete")

func _exit_tree():
	if _camera_thread and _camera_thread.is_started():
		_camera_thread.wait_to_finish()
	_camera_mutex = null
	_camera_semaphore = null

# Handle keyboard shortcuts
func _unhandled_key_input(event) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				if video_player and video_player.has_method("toggle_playback"):
					video_player.toggle_playback()
			KEY_LEFT, KEY_RIGHT:
				if timeline_editor:
					timeline_editor._unhandled_key_input(event)
			# Add mode switching shortcuts
			KEY_1:
				if has_node("ModeSelector"):
					$ModeSelector._on_video_mode()
			KEY_2:
				if has_node("ModeSelector"):
					$ModeSelector._on_camera_mode()
			KEY_3:
				if has_node("ModeSelector"):
					$ModeSelector._on_subtitles_mode()
			KEY_4:
				if has_node("ModeSelector"):
					$ModeSelector._on_compositing_mode()
			KEY_5:
				if has_node("ModeSelector"):
					$ModeSelector._on_layers_mode()
			KEY_6:
				if has_node("ModeSelector"):
					$ModeSelector._on_effects_mode()

# Video importer functionality
func _setup_video_importer():
	if not video_importer and video_importer_scene:
		video_importer = video_importer_scene.instantiate()
		add_child(video_importer)
		video_importer.hide()

		# Connect signals
		if video_importer.has_signal("media_imported"):
			video_importer.media_imported.connect(_on_media_imported)
		if video_importer.has_signal("timeline_updated"):
			video_importer.timeline_updated.connect(_on_timeline_updated)

func _on_import_pressed():
	if not video_importer:
		_setup_video_importer()

	if video_importer:
		video_importer.show_importer()
		print("[MainEditor] Video importer opened")

func _on_media_imported(file_path: String, media_type: String):
	print("[MainEditor] Media imported: " + file_path + " (type: " + media_type + ")")

	# Update video player if it's a video file
	if media_type == "video" and video_player:
		# Load the video into the video player
		var video_stream = load(file_path) as VideoStream
		if video_stream:
			video_player.stream = video_stream
			if timeline_editor:
				timeline_editor.set_video_duration(video_stream.get_length())
			print("[MainEditor] Video loaded into player: " + file_path)

func _on_timeline_updated(media_list: Array):
	print("[MainEditor] Timeline updated with " + str(media_list.size()) + " items")

	# Here you could update the timeline editor with the media list
	# For now, just load the first video if available
	for media_item in media_list:
		if media_item.media_type == "video":
			var video_stream = load(media_item.file_path) as VideoStream
			if video_stream and video_player:
				video_player.stream = video_stream
				if timeline_editor:
					timeline_editor.set_video_duration(video_stream.get_length())
				print("[MainEditor] First video from timeline loaded: " + media_item.file_path)
				break
