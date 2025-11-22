extends Control

class_name TimelineEditor

signal trim_changed(start_time: float, end_time: float)
signal seek_position(position: float)
signal playback_speed_changed(speed: float)

@onready var timeline: TextureProgressBar = $Timeline
@onready var start_handle: TextureRect = $Timeline/StartHandle
@onready var end_handle: TextureRect = $Timeline/EndHandle
@onready var position_indicator: TextureRect = $Timeline/PositionIndicator
@onready var speed_slider: HSlider = $SpeedControl

var video_duration: float = 0.0
var start_time: float = 0.0
var end_time: float = 0.0
var is_dragging_start: bool = false
var is_dragging_end: bool = false
var is_dragging_position: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var frame_snap: float = 1.0/60.0  # Snap to 60fps frames

# Zoom and scroll variables
var zoom_level: float = 1.0
var scroll_position: float = 0.0
var visible_duration: float = 10.0  # Seconds visible in timeline

func _ready():
	if not timeline or not start_handle or not end_handle or not position_indicator or not speed_slider:
		push_error("Timeline components not found")
		return

	speed_slider.value = 1.0
	if not speed_slider.is_connected("value_changed", _on_speed_changed):
		speed_slider.connect("value_changed", _on_speed_changed)

func set_video_duration(duration: float):
	if duration <= 0:
		push_error("Invalid video duration")
		return

	video_duration = duration
	end_time = duration
	_update_handles()

func _update_handles():
	if not timeline or not start_handle or not end_handle:
		return

	var timeline_width = timeline.size.x
	start_handle.position.x = (start_time / video_duration) * timeline_width
	end_handle.position.x = (end_time / video_duration) * timeline_width

	# Update zoom view
	var zoom_start = scroll_position
	var zoom_end = scroll_position + (visible_duration / zoom_level)
	timeline.min_value = zoom_start
	timeline.max_value = zoom_end

func _input(event):
	if not timeline or not start_handle or not end_handle or not position_indicator:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var handle_width = start_handle.size.x

			# Check if clicking on handles or position indicator
			if event.position.distance_to(start_handle.global_position) < handle_width:
				is_dragging_start = event.pressed
				drag_offset = start_handle.position - event.position
			elif event.position.distance_to(end_handle.global_position) < handle_width:
				is_dragging_end = event.pressed
				drag_offset = end_handle.position - event.position
			elif event.position.distance_to(position_indicator.global_position) < handle_width:
				is_dragging_position = event.pressed
				drag_offset = position_indicator.position - event.position

		# Zoom with mouse wheel
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_timeline(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_timeline(0.9)

	elif event is InputEventMouseMotion:
		if is_dragging_start:
			_drag_start_handle(event.position + drag_offset)
		elif is_dragging_end:
			_drag_end_handle(event.position + drag_offset)
		elif is_dragging_position:
			_drag_position_indicator(event.position + drag_offset)

func _drag_start_handle(new_pos: Vector2):
	if not timeline:
		return

	var timeline_width = timeline.size.x
	var new_time = (new_pos.x / timeline_width) * video_duration
	new_time = snapped(new_time, frame_snap)  # Snap to frames
	start_time = clamp(new_time, 0, end_time - frame_snap)
	_update_handles()
	emit_signal("trim_changed", start_time, end_time)

func _drag_end_handle(new_pos: Vector2):
	if not timeline:
		return

	var timeline_width = timeline.size.x
	var new_time = (new_pos.x / timeline_width) * video_duration
	new_time = snapped(new_time, frame_snap)  # Snap to frames
	end_time = clamp(new_time, start_time + frame_snap, video_duration)
	_update_handles()
	emit_signal("trim_changed", start_time, end_time)

func _drag_position_indicator(new_pos: Vector2):
	if not timeline or not position_indicator:
		return

	var timeline_width = timeline.size.x
	var new_time = (new_pos.x / timeline_width) * video_duration
	new_time = snapped(new_time, frame_snap)  # Snap to frames
	new_time = clamp(new_time, start_time, end_time)
	emit_signal("seek_position", new_time)

func _zoom_timeline(factor: float):
	zoom_level *= factor
	zoom_level = clamp(zoom_level, 1.0, 20.0)  # Limit zoom range
	visible_duration = video_duration / zoom_level
	_update_handles()

func _on_speed_changed(value: float):
	emit_signal("playback_speed_changed", value)

# Frame-accurate navigation
func next_frame():
	if not position_indicator:
		return
	var new_time = position_indicator.position.x + frame_snap
	emit_signal("seek_position", new_time)

func prev_frame():
	if not position_indicator:
		return
	var new_time = position_indicator.position.x - frame_snap
	emit_signal("seek_position", new_time)

# Keyboard shortcuts
func _unhandled_key_input(event) -> void:
	if not position_indicator:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				if event.shift_pressed:
					prev_frame()
				else:
					emit_signal("seek_position", position_indicator.position.x - 1.0)
			KEY_RIGHT:
				if event.shift_pressed:
					next_frame()
				else:
					emit_signal("seek_position", position_indicator.position.x + 1.0)
			KEY_SPACE:
				var parent = get_parent()
				if parent and parent.has_method("toggle_playback"):
					parent.toggle_playback()
