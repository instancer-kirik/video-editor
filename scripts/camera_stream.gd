extends VideoStream

class_name CameraStream

var _active: bool = false
var _device_path: String = ""
var _width: int = 640
var _height: int = 480
var _texture: ImageTexture
var _debug: bool = true
var _process: int = -1
var _thread: Thread
var _mutex: Mutex
var _frame_data: PackedByteArray
var _should_exit: bool = false

func _debug_print(msg: String):
	if _debug:
		print("[CameraStream] " + msg)
		
func _debug_error(msg: String):
	if _debug:
		push_error("[CameraStream] " + msg)
	else:
		push_error(msg)

func _init():
	_debug_print("Initializing CameraStream")
	_texture = ImageTexture.create_from_image(Image.create(_width, _height, false, Image.FORMAT_RGB8))
	_mutex = Mutex.new()
	_thread = Thread.new()
	_debug_print("Initialization complete")

func _check_device_formats(path: String) -> Dictionary:
	var output = []
	var formats = {"width": 640, "height": 480, "format": ""}
	
	# Check if v4l2-ctl is available
	var exit_code = OS.execute("which", ["v4l2-ctl"], output)
	if exit_code != 0:
		_debug_error("v4l2-ctl not found, please install v4l-utils")
		return formats
		
	# Get device driver info
	output.clear()
	exit_code = OS.execute("v4l2-ctl", ["--device=" + path, "--info"], output)
	_debug_print("Device info: " + str(output))
	
	# List supported formats
	output.clear()
	exit_code = OS.execute("v4l2-ctl", ["--device=" + path, "--list-formats-ext"], output)
	_debug_print("Supported formats: " + str(output))
	
	# Parse formats to find the best one
	var format_text = str(output)
	if format_text.contains("MJPG"):
		formats["format"] = "image/jpeg"
	elif format_text.contains("YUYV"):
		formats["format"] = "video/x-raw,format=YUY2"
	else:
		formats["format"] = "video/x-raw"
	
	# Try to find supported resolutions
	if format_text.contains("640x480"):
		formats["width"] = 640
		formats["height"] = 480
	elif format_text.contains("1280x720"):
		formats["width"] = 1280
		formats["height"] = 720
	elif format_text.contains("1920x1080"):
		formats["width"] = 1920
		formats["height"] = 1080
	
	return formats

func set_device(path: String, width: int = 640, height: int = 480) -> bool:
	_debug_print("Setting device: " + path + " (" + str(width) + "x" + str(height) + ")")
	_device_path = path
	
	# Check device permissions and group membership
	var output = []
	OS.execute("ls", ["-l", path], output)
	_debug_print("Device permissions: " + str(output))
	
	# Check user's group membership
	output.clear()
	OS.execute("groups", [], output)
	_debug_print("User groups: " + str(output))
	
	# Check if device exists and is accessible
	if not FileAccess.file_exists(path):
		_debug_error("Camera device not found: " + path)
		return false
		
	# Check device formats and capabilities
	var formats = _check_device_formats(path)
	_width = width
	_height = height
	
	# Test if gst-launch-1.0 is available
	output.clear()
	var exit_code = OS.execute("which", ["gst-launch-1.0"], output)
	if exit_code != 0:
		_debug_error("gst-launch-1.0 not found, please install gstreamer1.0-tools")
		return false
	
	# Test camera with GStreamer using detected format
	output.clear()
	var format_str = formats["format"]
	var test_pipeline = [
		"gst-launch-1.0",
		"-v",  # Verbose output
		"v4l2src", "device=" + path,
		"!", format_str + ",width=" + str(width) + ",height=" + str(height),
	]
	
	if format_str == "image/jpeg":
		test_pipeline += ["!", "jpegdec"]
	
	test_pipeline += [
		"!", "videoconvert",
		"!", "video/x-raw,format=RGB",
		"!", "fakesink",
		"num-buffers=1"  # Only try to capture one frame
	]
	
	_debug_print("Testing GStreamer pipeline: " + str(test_pipeline))
	exit_code = OS.execute("sh", ["-c", " ".join(test_pipeline) + " 2>&1"], output)
	_debug_print("GStreamer test result: " + str(output))
	
	if str(output).contains("error"):
		_debug_error("Failed to initialize camera with format: " + format_str)
		return false
	
	return true

func is_active() -> bool:
	return _active

func get_texture() -> Texture2D:
	_mutex.lock()
	var tex = _texture
	_mutex.unlock()
	return tex

func get_length() -> float:
	return 0.0

func get_playback_position() -> float:
	return 0.0

func _camera_thread_function():
	_debug_print("Starting camera thread")
	
	# Create unique identifiers for this instance
	var pid = OS.get_process_id()
	var pipe_path = "/tmp/camera_pipe_" + str(pid)
	var error_path = "/tmp/gst_error_" + str(pid)
	
	# Ensure cleanup of any existing files
	OS.execute("rm", ["-f", pipe_path])
	OS.execute("rm", ["-f", error_path])
	
	# Create a named pipe
	OS.execute("mkfifo", [pipe_path])
	
	# Get supported formats
	var formats = _check_device_formats(_device_path)
	var format_str = formats["format"]
	
	# Build GStreamer pipeline with appsink
	var pipeline = [
		"gst-launch-1.0",
		"-v",
		"v4l2src", "device=" + _device_path,
		"!", "video/x-raw,format=YUY2,width=" + str(_width) + ",height=" + str(_height) + ",framerate=30/1",
		"!", "videoconvert",
		"!", "tee", "name=t",
		"t.", "!", "queue", "!", "video/x-raw,format=RGB",
		"!", "filesink", "location=" + pipe_path,
		"t.", "!", "queue", "!", "videoconvert",
		"!", "autovideosink", "sync=false"
	]
	
	_debug_print("Starting GStreamer with pipeline: " + str(pipeline))
	
	# Start GStreamer in the background with error redirection
	var cmd = " ".join(pipeline) + " 2>" + error_path + " & echo $!"
	var output = []
	var exit_code = OS.execute("sh", ["-c", cmd], output)
	
	if output.size() > 0:
		_process = output[0].to_int()  # Store the process ID
		if _process > 0:
			_debug_print("GStreamer process started with PID: " + str(_process))
		else:
			_debug_error("Invalid process ID returned: " + str(_process))
			_cleanup_resources(pipe_path, error_path)
			return
	else:
		_debug_error("Failed to start GStreamer process")
		_cleanup_resources(pipe_path, error_path)
		return
	
	# Wait a bit for GStreamer to start
	OS.delay_msec(1000)
	
	# Check for startup errors
	var error_file = FileAccess.open(error_path, FileAccess.READ)
	if error_file:
		var error_text = error_file.get_as_text()
		error_file.close()
		if error_text.length() > 0:
			_debug_error("GStreamer startup errors: " + error_text)
			
			# Try alternative pipeline if initial one failed
			if error_text.contains("negotiation failed"):
				_debug_print("Trying alternative pipeline...")
				_cleanup_resources(pipe_path, error_path)
				
				# Recreate pipe
				OS.execute("mkfifo", [pipe_path])
				
				# Alternative pipeline using MJPG format
				pipeline = [
					"gst-launch-1.0",
					"-v",
					"v4l2src", "device=" + _device_path,
					"!", "image/jpeg,width=" + str(_width) + ",height=" + str(_height) + ",framerate=30/1",
					"!", "jpegdec",
					"!", "videoconvert",
					"!", "tee", "name=t",
					"t.", "!", "queue", "!", "video/x-raw,format=RGB",
					"!", "filesink", "location=" + pipe_path,
					"t.", "!", "queue", "!", "videoconvert",
					"!", "autovideosink", "sync=false"
				]
				
				_debug_print("Starting alternative GStreamer pipeline: " + str(pipeline))
				cmd = " ".join(pipeline) + " 2>" + error_path + " & echo $!"
				output.clear()
				exit_code = OS.execute("sh", ["-c", cmd], output)
				
				if output.size() > 0:
					_process = output[0].to_int()
					if _process <= 0:
						_debug_error("Invalid process ID returned for alternative pipeline: " + str(_process))
						_cleanup_resources(pipe_path, error_path)
						return
				else:
					_debug_error("Failed to start alternative GStreamer pipeline")
					_cleanup_resources(pipe_path, error_path)
					return
				
				# Wait again for GStreamer to start
				OS.delay_msec(1000)
	
	# Create an image to hold the frame data
	var image = Image.create(_width, _height, false, Image.FORMAT_RGB8)
	var frame_size = _width * _height * 3  # RGB format = 3 bytes per pixel
	var frame_count = 0
	
	# Open the pipe for reading
	var pipe = FileAccess.open(pipe_path, FileAccess.READ)
	if not pipe:
		_debug_error("Failed to open GStreamer output pipe")
		_cleanup_resources(pipe_path, error_path)
		return
	
	_debug_print("Started reading from GStreamer pipe")
	
	while not _should_exit:
		if not pipe.is_open():
			_debug_error("Pipe was closed unexpectedly")
			break
			
		var frame_data = pipe.get_buffer(frame_size)
		if frame_data.size() == frame_size:
			if frame_count == 0:
				_debug_print("First frame captured, size: " + str(frame_data.size()))
			
			image.set_data(_width, _height, false, Image.FORMAT_RGB8, frame_data)
			
			_mutex.lock()
			_texture.update(image)
			_mutex.unlock()
			
			if frame_count == 0:
				_debug_print("First frame displayed")
			
			frame_count += 1
		else:
			if frame_count == 0:
				_debug_error("Invalid frame size: " + str(frame_data.size()) + " (expected " + str(frame_size) + ")")
			break
		
		OS.delay_msec(16)  # ~60fps
	
	# Cleanup
	_debug_print("Cleaning up camera thread")
	_cleanup_resources(pipe_path, error_path)
	_debug_print("Camera thread exiting after " + str(frame_count) + " frames")

func _cleanup_resources(pipe_path: String, error_path: String):
	# Kill the GStreamer process first
	if _process > 0:
		OS.execute("kill", [str(_process)])
		_process = -1
	
	# Kill any remaining GStreamer processes for this device
	OS.execute("pkill", ["-f", "gst-launch-1.0.*" + _device_path])
	
	# Remove temporary files
	OS.execute("rm", ["-f", pipe_path])
	OS.execute("rm", ["-f", error_path])

func start():
	if not _active:
		_debug_print("Starting camera...")
		_active = true
		_should_exit = false
		
		# Start the camera thread
		_thread.start(Callable(self, "_camera_thread_function"))

func stop():
	if _active:
		_debug_print("Stopping camera...")
		_active = false
		_should_exit = true
		
		# Wait for thread to finish with timeout
		var timeout = Time.get_ticks_msec() + 5000  # 5 second timeout
		while _thread.is_alive() and Time.get_ticks_msec() < timeout:
			OS.delay_msec(100)
		
		if _thread.is_alive():
			_debug_error("Thread did not stop gracefully, forcing cleanup")
			# Force cleanup if thread didn't stop
			_cleanup_resources("/tmp/camera_pipe_" + str(OS.get_process_id()), 
							 "/tmp/gst_error_" + str(OS.get_process_id()))
		
		_debug_print("Camera stopped")

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		_debug_print("CameraStream being deleted, stopping camera")
		stop()  # Ensure camera is stopped when object is deleted 

func start_recording(output_path: String) -> bool:
	if not _active:
		return false
		
	# Build recording pipeline
	var record_pipeline = [
		"gst-launch-1.0",
		"-v",
		"v4l2src", "device=" + _device_path,
		"!", "video/x-raw,format=YUY2,width=" + str(_width) + ",height=" + str(_height) + ",framerate=30/1",
		"!", "videoconvert",
		"!", "x264enc",
		"!", "mp4mux",
		"!", "filesink", "location=" + output_path
	]
	
	_debug_print("Starting recording with pipeline: " + str(record_pipeline))
	
	# Start recording process
	var output = []
	var exit_code = OS.execute("sh", ["-c", " ".join(record_pipeline) + " &"], output)
	
	return exit_code == 0

func stop_recording():
	# Find and kill the recording process
	OS.execute("pkill", ["-f", "gst-launch-1.0.*" + _device_path + ".*x264enc"]) 
