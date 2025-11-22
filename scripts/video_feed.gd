extends Node

# Video data structure
class VideoData:
	var path: String
	var stream: VideoStream
	var author: String
	var likes: int
	var description: String
	var sound_name: String
	var is_following: bool
	var is_liked: bool
	var is_bookmarked: bool
	var comment_count: int
	var share_count: int
	var subtitles: Dictionary  # Dictionary of language code -> array of subtitle entries
	
	func _init(p: String, s: VideoStream = null, auth: String ="", desc: String ="", sound: String = "Original Sound"):
		path = p
		stream = s
		author = auth
		description = desc
		sound_name = sound
		likes = 0
		is_following = false
		is_liked = false
		is_bookmarked = false
		comment_count = 0
		share_count = 0
		subtitles = {}

class SubtitleEntry:
	var start_time: float
	var end_time: float
	var text: String
	
	func _init(start: float, end: float, content: String):
		start_time = snapped(start, 0.001)  # Round to milliseconds
		end_time = snapped(end, 0.001)
		text = content

# Array of videos in the feed
var videos: Array[VideoData] = []
var current_index: int = 0
var current_video: VideoData = null

# Signals
signal video_changed(video_data: VideoData)
signal like_pressed(video_index: int)
signal bookmark_pressed(video_index: int)
signal follow_changed(author: String, is_following: bool)
signal preview_updated

var _camera_process: int = -1
var _pipe_path: String = ""
var _pipe_file: FileAccess = null
var _preview_texture: ImageTexture = null
var _preview_image: Image = null
var _current_device: String = ""
var _current_resolution: String = ""
var _recording: bool = false
var _recording_file: FileAccess = null

func _ready():
	# Make this a singleton
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preview_texture = ImageTexture.create_from_image(Image.create(640, 480, false, Image.FORMAT_RGB8))
	_preview_image = Image.create(640, 480, false, Image.FORMAT_RGB8)

func _load_sample_videos():
	var video1 = VideoData.new(
		"res://videos/sample1.mp4",
		null,
		"user1",
		"First video! #trending #viral",
		"DJ Awesome - Summer Vibes"
	)
	_add_sample_subtitles(video1)
	videos.append(video1)
	
	var video2 = VideoData.new(
		"res://videos/sample2.mp4",
		null,
		"user2",
		"Another cool video 🔥 #dance",
		"Original Sound - user2"
	)
	_add_sample_subtitles(video2)
	videos.append(video2)

func _add_sample_subtitles(video: VideoData):
	# English subtitles
	var en_subs = [
		SubtitleEntry.new(0.0, 2.0, "Hey everyone!"),
		SubtitleEntry.new(2.0, 4.0, "Check out this cool video"),
		SubtitleEntry.new(4.0, 6.0, "Don't forget to like and follow!")
	]
	video.subtitles["en"] = en_subs
	
	# Spanish subtitles
	var es_subs = [
		SubtitleEntry.new(0.0, 2.0, "¡Hola a todos!"),
		SubtitleEntry.new(2.0, 4.0, "Miren este video genial"),
		SubtitleEntry.new(4.0, 6.0, "¡No olviden dar me gusta y seguir!")
	]
	video.subtitles["es"] = es_subs
	
	# Add more languages as needed...

func get_subtitle_at_time(time: float, language: String = "en") -> String:
	var current_video = get_current_video()
	if !current_video or !current_video.subtitles.has(language):
		return ""
		
	var subs = current_video.subtitles[language]
	for sub in subs:
		if time >= sub.start_time and time < sub.end_time:
			return sub.text
	
	return ""

func next_video():
	if current_index < videos.size() - 1:
		current_index += 1
		emit_signal("video_changed", videos[current_index])

func previous_video():
	if current_index > 0:
		current_index -= 1
		emit_signal("video_changed", videos[current_index])

func like_current_video():
	if current_index >= 0 and current_index < videos.size():
		var video = videos[current_index]
		if !video.is_liked:
			video.likes += 1
			video.is_liked = true
			emit_signal("like_pressed", current_index)

func bookmark_current_video():
	if current_index >= 0 and current_index < videos.size():
		var video = videos[current_index]
		video.is_bookmarked = !video.is_bookmarked
		emit_signal("bookmark_pressed", current_index)

func toggle_follow_current_author():
	if current_index >= 0 and current_index < videos.size():
		var video = videos[current_index]
		video.is_following = !video.is_following
		emit_signal("follow_changed", video.author, video.is_following)

func get_current_video() -> VideoData:
	return current_video

func load_video(path: String):
	var stream: VideoStream
	if path.ends_with(".ogv"):
		stream = VideoStreamTheora.new()
	else:
		stream = VideoStream.new()
	stream.file = path
	
	current_video = VideoData.new(path, stream, "", "", "")
	emit_signal("video_changed", current_video)

func set_camera_feed(stream: VideoStream):
	current_video = VideoData.new("camera", stream, "", "", "")
	emit_signal("video_changed", current_video)

func get_available_devices() -> Array:
	var devices = []
	for i in range(10):  # Check first 10 possible video devices
		var path = "/dev/video%d" % i
		if FileAccess.file_exists(path):
			devices.append(path)
	return devices

func get_device_resolutions(device: String) -> Array:
	var output = []
	var args = ["-d", device, "--list-formats-ext"]
	var exit_code = OS.execute("v4l2-ctl", args)
	
	if exit_code == 0:
		# Parse the output to get supported resolutions
		# For now, return some common resolutions
		output = [
			"640x480",
			"1280x720",
			"1920x1080"
		]
	
	return output

func start_camera(device: String, resolution: String = "640x480") -> bool:
	if _camera_process != -1:
		stop_camera()
	
	_current_device = device
	_current_resolution = resolution
	
	# Create a named pipe for FFmpeg output
	_pipe_path = "/tmp/camera_pipe_%d" % OS.get_process_id()
	OS.execute("mkfifo", [_pipe_path])
	
	# Start FFmpeg process
	var size = resolution.split("x")
	var width = size[0]
	var height = size[1]
	
	var args = [
		"-f", "video4linux2",
		"-i", device,
		"-s", resolution,
		"-r", "30",
		"-f", "rawvideo",
		"-pix_fmt", "rgb24",
		_pipe_path
	]
	
	_camera_process = OS.create_process("ffmpeg", args)
	
	if _camera_process != -1:
		# Open the pipe for reading
		_pipe_file = FileAccess.open(_pipe_path, FileAccess.READ)
		if _pipe_file:
			return true
	
	stop_camera()
	return false

func stop_camera():
	if _camera_process != -1:
		OS.kill(_camera_process)
		_camera_process = -1
	
	if _pipe_file:
		_pipe_file.close()
		_pipe_file = null
	
	if _pipe_path != "":
		OS.execute("rm", [_pipe_path])
		_pipe_path = ""
	
	if _recording:
		stop_recording()

func start_recording() -> bool:
	if not _camera_process != -1:
		return false
	
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var filename = "camera_recording_%s.mp4" % timestamp
	
	var args = [
		"-f", "video4linux2",
		"-i", _current_device,
		"-s", _current_resolution,
		"-r", "30",
		filename
	]
	
	var recording_process = OS.create_process("ffmpeg", args)
	if recording_process != -1:
		_recording = true
		return true
	
	return false

func stop_recording():
	if _recording:
		_recording = false

func get_preview_texture() -> ImageTexture:
	if _pipe_file and _camera_process != -1:
		var size = _current_resolution.split("x")
		var width = int(size[0])
		var height = int(size[1])
		var bytes_per_pixel = 3  # RGB format
		var frame_size = width * height * bytes_per_pixel
		
		var frame_data = _pipe_file.get_buffer(frame_size)
		if frame_data.size() == frame_size:
			_preview_image.set_data(width, height, false, Image.FORMAT_RGB8, frame_data)
			_preview_texture.update(_preview_image)
			preview_updated.emit()
	
	return _preview_texture

func set_resolution(device: String, resolution: String):
	if device == _current_device and _camera_process != -1:
		stop_camera()
		start_camera(device, resolution) 
