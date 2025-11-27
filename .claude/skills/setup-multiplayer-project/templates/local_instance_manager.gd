extends RefCounted
class_name LocalInstanceManager

var _paths: Dictionary = {}
var _executable_paths: Dictionary = {}
var _log_folder: String = ""
var _environment: String = "development"
var _lobby_url: String = ""
var _logger: CustomLogger


func _init(
	paths: Dictionary = {},
	executable_paths: Dictionary = {},
	log_folder: String = "",
	environment: String = "development",
	lobby_url: String = ""
):
	_paths = paths
	_executable_paths = executable_paths
	_log_folder = log_folder
	_environment = environment
	_lobby_url = lobby_url
	_logger = CustomLogger.new("LocalInstanceManager")


func spawn(game: String, code: String, port: int) -> Dictionary:
	var root := _get_root(game)
	var executable_path := _get_executable_path(game)
	var log_path := _get_log_path(code)
	var args := _get_args(code, port)

	args = _add_root_to_args(root, args)
	args = _add_log_path_to_args(log_path, args)
	args = _add_lobby_url_to_args(args)

	_logger.info("Spawning game server: " + executable_path + " " + " ".join(args), "spawn")

	var pid := OS.create_process(executable_path, args)
	if pid == -1:
		var error_msg := "Failed to spawn process for game: " + game
		_logger.error(error_msg, "spawn")
		return {"success": false, "error": error_msg}

	_logger.info("Spawned game server with PID: " + str(pid) + ", code: " + code + ", port: " + str(port), "spawn")
	return {"success": true, "error": "", "pid": pid}


func _get_root(game: String) -> String:
	if _paths.has(game):
		return _paths[game]
	return ProjectSettings.globalize_path("res://")


func _get_executable_path(game: String) -> String:
	if _executable_paths.has(game):
		return _executable_paths[game]
	return OS.get_executable_path()


func _get_log_path(code: String) -> String:
	if _log_folder.is_empty():
		return ""
	var dir := DirAccess.open(_log_folder)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(_log_folder)
	return _log_folder.path_join(code + ".log")


func _get_args(code: String, port: int) -> PackedStringArray:
	return PackedStringArray([
		"--headless",
		"server_type=room",
		"environment=" + _environment,
		"code=" + code,
		"port=" + str(port)
	])


func _add_log_path_to_args(log_path: String, args: PackedStringArray) -> PackedStringArray:
	if log_path.is_empty():
		return args
	args.append("log_path=" + log_path)
	return args


func _add_root_to_args(root: String, args: PackedStringArray) -> PackedStringArray:
	if root.is_empty():
		return args
	args.insert(0, "--path")
	args.insert(1, root)
	return args


func _add_lobby_url_to_args(args: PackedStringArray) -> PackedStringArray:
	if _lobby_url.is_empty():
		return args
	args.append("--lobby_url=" + _lobby_url)
	return args
