extends Node
class_name LobbyServer

# Autoload named Lobby
const DEFAULT_SERVER_IP = "127.0.0.1"  # IPv4 localhost
const MIN_PORT = 18000
const MAX_PORT = 19000

var lobbies: Dictionary = {}
var clients: Dictionary = {}

var _logger: CustomLogger

var codes: Array[String]:
	get:
		var result: Array[String]
		result.assign(lobbies.values().map(func(lobby_info): return lobby_info.code))
		return result

var _server: WebSocketServer

# Folder in which logs will be stored
var _log_folder: String
# Paths of available games
var _paths: Dictionary
# Environnement it determines how a lobby should be created
var _environment: String


func _init(paths: Dictionary = {}, log_folder: String = "", environment: String = "development"):
	_log_folder = log_folder
	_paths = paths
	_environment = environment
	_logger = CustomLogger.new("LobbyServer")


func _find_free_port_in_range(min_port: int, max_port: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var tried_ports := []
	var total_ports := max_port - min_port + 1

	while tried_ports.size() < total_ports:
		var port := rng.randi_range(min_port, max_port)
		if port in tried_ports:
			continue

		tried_ports.append(port)

		var server := TCPServer.new()
		var err := server.listen(port)
		if err == OK:
			server.stop()
			return port  # Port disponible

	_logger.error(
		"Aucun port libre trouvé dans la plage [%d, %d]" % [min_port, max_port],
		"_find_free_port_in_range"
	)
	return -1  # Aucun port libre trouvé


func _generate_code(banned_codes: Array[String], length: int = 6) -> String:
	var chars := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var attempt := 0
	var max_attempts := 1000  # Sécurité anti-boucle infinie

	while attempt < max_attempts:
		var code := ""
		for i in length:
			code += chars[rng.randi_range(0, chars.length() - 1)]

		if not banned_codes.has(code):
			return code

		attempt += 1

	_logger.error(
		"Impossible de générer un code unique après %d tentatives" % max_attempts, "_generate_code"
	)
	return ""


func _build_message(message) -> String:
	return JSON.stringify(message)


func _build_lobby_created_message(code) -> String:
	return _build_message({"type": "lobby_created", "data": code})


func _build_lobby_connected_message(peer_id, lobby_info) -> String:
	return _build_message(
		{"type": "lobby_connected", "data": {"peer_id": peer_id, "lobby_info": lobby_info}}
	)


func _filter_dict(dict: Dictionary, callback: Callable) -> Dictionary:
	var result := {}
	for key in dict.keys():
		var value = dict[key]
		if callback.call(key, value):
			result[key] = value
	return result


func _get_lobbies_for_game(game: String) -> Dictionary:
	return _filter_dict(lobbies, func(peer_id, lobby_info): return lobby_info.game == game)


func _get_peer_ids_for_game(game: String) -> Array[int]:
	var result: Array[int]
	var clients_for_game := _filter_dict(clients, func(peer_id, info): return info.game == game)
	result.assign(clients_for_game.keys())
	return result


func _build_lobby_updated_message(game) -> String:
	return _build_message({"type": "lobbies_updated", "data": _get_lobbies_for_game(game)})


func _on_server_message_received(peer_id: int, message: String):
	_logger.debug(
		"_on_server_message_received (" + str(peer_id) + "): " + message,
		"_on_server_message_received"
	)
	var parsed_message = JSON.parse_string(message)
	if parsed_message.type == "create_lobby":
		var game = parsed_message.data.game
		var code = _create_lobby(game)
		_server.send(peer_id, _build_lobby_created_message(code))
	elif parsed_message.type == "register_lobby":
		lobbies[peer_id] = parsed_message.data

		var game = lobbies[peer_id].game
		var peer_ids := _get_peer_ids_for_game(game)

		_server.broadcast(peer_ids, _build_lobby_updated_message(game))
		_server.broadcast(peer_ids, _build_lobby_connected_message(peer_id, parsed_message.data))
	elif parsed_message.type == "register_client":
		clients[peer_id] = parsed_message.data
		var game = clients[peer_id].game

		_server.send(peer_id, _build_lobby_updated_message(game))


func start(port):
	_logger.info("create on port " + str(port), "create")
	_server = WebSocketServer.new()

	_server.client_connected.connect(_on_client_connected)
	_server.client_disconnected.connect(_on_client_disconnected)
	_server.message_received.connect(_on_server_message_received)

	var error = _server.listen(port)
	if error:
		_logger.error("Failed to create server on port " + str(port) + ": " + str(error), "create")
		return error
	_logger.info("✅ Server created on port " + str(port), "create")


func stop():
	if _server:
		_server.stop()


func _join_path(parts: Array) -> String:
	var clean_parts := []
	for part: String in parts:
		clean_parts.append(part)
	return "/".join(clean_parts)


func _get_log_path(code: String) -> String:
	if not _log_folder.is_empty():
		var log_folder = _log_folder
		if not DirAccess.dir_exists_absolute(log_folder):
			var error = DirAccess.make_dir_absolute(log_folder)
			if error:
				_logger.error("Can't create logs folder " + log_folder, "_create_lobby")
		return _join_path([log_folder, code + ".log"])
	return ""


func _get_root(game) -> String:
	return (
		_paths[game]
		if not _paths.is_empty() and _paths.has(game)
		else ProjectSettings.globalize_path("res://")
	)


func _get_args(code: String, port: int) -> PackedStringArray:
	return PackedStringArray(
		[
			"--headless",
			"server_type=room",
			"environment=" + _environment,
			"code=" + code,
			"port=" + str(port)
		]
	)


func _add_log_path_to_args(log_path, args) -> void:
	if not log_path.is_empty():
		args = (
			args
			+ PackedStringArray(
				[
					"--log-file",
					log_path,
				]
			)
		)


func _add_root_to_args(root, args) -> void:
	if not root.is_empty():
		args = (
			args
			+ PackedStringArray(
				[
					"--path",
					root,
				]
			)
		)


func _create_lobby(game: String):
	_logger.info("Creating new lobby with auto-generated code", "_create_lobby")
	var code := _generate_code(codes)
	var port := _find_free_port_in_range(MIN_PORT, MAX_PORT)
	var root := _get_root(game)
	var log_path := _get_log_path(code)
	var args := _get_args(code, port)

	_add_log_path_to_args(log_path, args)

	if _environment == "production":
		_logger.debug("Args: " + str(args), "_create_lobby")
		OS.create_process(root, args)
	else:
		_add_root_to_args(root, args)
		_logger.debug("Args: " + str(args), "_create_lobby")
		OS.create_instance(args)
	return code


func _on_client_connected(id):
	_logger.info("peer connected " + str(id), "_on_client_connected")
	# _server.send(id, JSON.stringify({"type": "lobbies_updated", "data": lobbies}))


func _on_client_disconnected(id):
	_logger.info("peer disconnected " + str(id), "_on_client_disconnected")
	if lobbies.has(id):
		lobbies.erase(id)
		_server.send(0, JSON.stringify({"type": "lobby_disconnected", "data": id}))
		_server.send(0, JSON.stringify({"type": "lobbies_updated", "data": lobbies}))
	elif clients.has(id):
		clients.erase(id)


func _process(delta):
	if _server:
		_server._process(delta)
