extends Node
## Tripo AI API client singleton

const TRIPO_BASE_URL: String = "https://api.tripo3d.ai/v2/openapi"
const MAX_POLL_RETRIES: int = 60
const POLL_INTERVAL: float = 2.0
const FORBIDDEN_WORDS: Array[String] = ["weapon", "gun", "bomb", "violence"]

var _api_key: String = ""
var _http: HTTPRequest = null
var _download_http: HTTPRequest = null
var _active_task_id: String = ""
var _poll_timer: Timer = null
var _poll_count: int = 0

signal model_ready(glb_path: String)
signal request_failed(error_msg: String)

func _ready() -> void:
	_load_api_key()
	_setup_http()
	_setup_download_http()
	_setup_timer()

func _load_api_key() -> void:
	var config := ConfigFile.new()

	# Try res:// first (editor mode), then user:// (exported)
	var paths := ["res://secrets.cfg", "user://secrets.cfg"]
	var loaded := false

	for path in paths:
		var err := config.load(path)
		if err == OK:
			loaded = true
			if OS.is_debug_build():
				print("Loaded API config from: %s" % path)
			break

	if not loaded:
		push_error("API configuration missing. Copy secrets.cfg.example to secrets.cfg and add your key.")
		return

	_api_key = config.get_value("tripo", "api_key", "")

	if _api_key.is_empty() or _api_key == "YOUR_TRIPO_API_KEY_HERE":
		push_error("API key not configured. Edit secrets.cfg with your Tripo API key.")

func _setup_http() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)

func _setup_download_http() -> void:
	_download_http = HTTPRequest.new()
	add_child(_download_http)
	_download_http.request_completed.connect(_on_download_completed)

func _setup_timer() -> void:
	_poll_timer = Timer.new()
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_on_poll_timeout)
	_poll_timer.one_shot = false

func _on_http_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	# _result and _headers: Required by HTTPRequest.request_completed signal signature
	if response_code < 200 or response_code >= 300:
		request_failed.emit("HTTP error: %d" % response_code)
		return

	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not json:
		request_failed.emit("Invalid JSON response")
		return

	_handle_response(json)

func request_model(prompt: String) -> void:
	if not _validate_prompt(prompt):
		return

	if _api_key.is_empty():
		request_failed.emit("API key not configured")
		return

	var headers := PackedStringArray([
		"Authorization: Bearer %s" % _api_key,
		"Content-Type: application/json"
	])

	var payload := JSON.stringify({
		"type": "text_to_model",
		"prompt": prompt,
		"model_version": "default",
	})

	var err := _http.request("%s/task" % TRIPO_BASE_URL, headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		request_failed.emit("HTTP request failed: %d" % err)

func _validate_prompt(prompt: String) -> bool:
	var length := prompt.length()

	if length < 10:
		request_failed.emit("Prompt too short (minimum 10 characters)")
		return false

	if length > 500:
		request_failed.emit("Prompt too long (maximum 500 characters)")
		return false

	var prompt_lower := prompt.to_lower()
	for word in FORBIDDEN_WORDS:
		if word in prompt_lower:
			request_failed.emit("Prompt contains forbidden content")
			return false

	return true

func _handle_response(data: Dictionary) -> void:
	if not data.has("data"):
		request_failed.emit("Missing 'data' field in response")
		return

	var task_data: Dictionary = data["data"]

	if task_data.has("status"):
		_handle_task_status(task_data)
		return

	if task_data.has("task_id"):
		_handle_task_created(task_data)
		return

	request_failed.emit("Unknown response format")

func _handle_task_created(task_data: Dictionary) -> void:
	_active_task_id = task_data["task_id"]
	_poll_count = 0
	_poll_timer.start(POLL_INTERVAL)

func _handle_task_status(task_data: Dictionary) -> void:
	var status: String = task_data.get("status", "")

	match status:
		"success":
			_poll_timer.stop()
			# Tripo API returns model URL in output.model or output.pbr_model
			var output: Variant = task_data.get("output", {})
			var model_url: String = ""

			if output is Dictionary:
				# Try different possible keys
				if output.has("model"):
					model_url = output["model"]
				elif output.has("pbr_model"):
					model_url = output["pbr_model"]
				elif output.has("base_model"):
					model_url = output["base_model"]

			if model_url.is_empty():
				if OS.is_debug_build():
					print("API response output: %s" % str(output))
				request_failed.emit("Success but no model URL in response")
			else:
				_download_model(model_url)

		"failed":
			_poll_timer.stop()
			var error_msg: String = task_data.get("error", "Unknown error")
			request_failed.emit("Model generation failed: %s" % error_msg)

		"processing", "queued", "running":
			pass

		_:
			_poll_timer.stop()
			request_failed.emit("Unknown status: %s" % status)

func _on_poll_timeout() -> void:
	_poll_count += 1

	if _poll_count >= MAX_POLL_RETRIES:
		_poll_timer.stop()
		request_failed.emit("Polling timeout exceeded")
		return

	_poll_task_status()

func _poll_task_status() -> void:
	if _active_task_id.is_empty():
		request_failed.emit("No active task to poll")
		return

	# Check if HTTP is busy
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return  # Skip this poll, try next interval

	var headers := PackedStringArray([
		"Authorization: Bearer %s" % _api_key
	])

	var url := "%s/task/%s" % [TRIPO_BASE_URL, _active_task_id]
	var err := _http.request(url, headers, HTTPClient.METHOD_GET)

	if err != OK:
		request_failed.emit("Poll request failed: %d" % err)
		_poll_timer.stop()

func _download_model(url: String) -> void:
	if url.is_empty():
		request_failed.emit("Empty model URL")
		return

	var err := _download_http.request(url)
	if err != OK:
		request_failed.emit("Download request failed: %d" % err)

func _on_download_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	# _result and _headers: Required by HTTPRequest.request_completed signal signature
	if response_code < 200 or response_code >= 300:
		request_failed.emit("Download failed: HTTP %d" % response_code)
		return

	if body.size() == 0:
		request_failed.emit("Downloaded file is empty")
		return

	if body.size() > 50 * 1024 * 1024:  # 50MB limit
		request_failed.emit("Downloaded file exceeds 50MB limit")
		return

	var local_path := _save_model(body)
	if local_path.is_empty():
		request_failed.emit("Failed to save model file")
		return

	model_ready.emit(local_path)

func _save_model(data: PackedByteArray) -> String:
	var dir_path := "user://models"
	var dir := DirAccess.open("user://")

	if not dir:
		push_error("Cannot access user directory")
		return ""

	if not dir.dir_exists("models"):
		var err := dir.make_dir("models")
		if err != OK:
			push_error("Failed to create models directory: %d" % err)
			return ""

	var timestamp := Time.get_unix_time_from_system()
	var filename := "weapon_%d_%d.glb" % [timestamp, randi()]
	var full_path := "%s/%s" % [dir_path, filename]

	var file := FileAccess.open(full_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to create file: %s" % full_path)
		return ""

	file.store_buffer(data)
	file.close()

	return full_path
