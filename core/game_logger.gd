extends Node

## Simple Logger to wrapper print statements and log to file if needed.
## Note: Godot's built-in file logging (debug/file_logging/enable_file_logging)
## already captures standard print() and errors. This class provides
## consistency and timestamping.

const LOG_FILE_PATH = "user://game_trace.log"

var _file: FileAccess

func _ready() -> void:
	# Optional: Open a separate trace log if we want to store specific game logic events
	# distinct from the engine log.
	_file = FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)
	if _file:
		_file.seek_end()
		log_info("Logger initialized. Session started.")
	else:
		print_rich("[color=red][Logger] Failed to open log file: %s[/color]" % LOG_FILE_PATH)

func _exit_tree() -> void:
	if _file:
		_file.close()

func info(msg: String) -> void:
	var timestamp = Time.get_time_string_from_system()
	var formatted = "[%s] [INFO] %s" % [timestamp, msg]
	print(formatted)
	_write_to_file(formatted)

func warn(msg: String) -> void:
	var timestamp = Time.get_time_string_from_system()
	var formatted = "[%s] [WARN] %s" % [timestamp, msg]
	print_rich("[color=yellow]%s[/color]" % formatted)
	_write_to_file(formatted)

func error(msg: String) -> void:
	var timestamp = Time.get_time_string_from_system()
	var formatted = "[%s] [ERROR] %s" % [timestamp, msg]
	print_rich("[color=red]%s[/color]" % formatted)
	# Also push to standard error so Godot debugger catches it
	printerr(formatted) 
	_write_to_file(formatted)

func log_info(msg: String) -> void: # Alias
	info(msg)

func _write_to_file(line: String) -> void:
	if _file:
		_file.store_line(line)
		# Flush occasionally? Or let OS handle it. 
		# For crash debugging, flush is safer but slower.
		_file.flush()
