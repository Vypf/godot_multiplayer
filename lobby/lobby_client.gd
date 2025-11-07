extends Node
class_name LobbyClient

# These signals can be connected to by a UI lobby scene or the game scene.
signal lobby_connected(peer_id: String, lobby_info: Dictionary)
signal lobby_disconnected(peer_id: String)
signal server_disconnected
signal lobby_created(code: String)

const DEFAULT_SERVER_IP = "127.0.0.1"  # IPv4 localhost

var lobbies: Dictionary = {}

@export var game: String
var lobby_info: Dictionary = {}:
	set(value):
		_logger.info("Set lobby info " + str(value), "lobby_info")
		if not value.is_empty():
			lobby_info.port = value.port
			lobby_info.code = value.code
			lobby_info.pId = value.pId
			lobby_info.game = game

var is_lobby: bool:
	get:
		return not lobby_info.is_empty()

var _logger: CustomLogger
var _client: WebSocketClient


func _init():
	_logger = CustomLogger.new("LobbyClient")


func create():
	if _client:
		_client.send(JSON.stringify({"type": "create_lobby", "data": {"game": game}}))


func stop():
	_client.clear()


func join(address: String = ""):
	_logger.info("Attempting to join lobby server at " + address, "join")
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	_client = WebSocketClient.new()

	_client.connected_to_server.connect(_on_connected_ok)
	_client.connection_closed.connect(_on_server_disconnected)
	_client.message_received.connect(_on_client_message_received)

	var error = _client.connect_to_url(address)
	if error != OK:
		_logger.error("Failed to connect to server " + address + ": " + str(error), "join")
		return error


func _on_client_message_received(message: Variant):
	_logger.debug("_on_client_message_received: " + message, "_on_client_message_received")
	var parsed_message = JSON.parse_string(message)
	if parsed_message.type == "lobby_created":
		lobby_created.emit(parsed_message.data)
	elif parsed_message.type == "lobbies_updated":
		lobbies = parsed_message.data
	elif parsed_message.type == "lobby_connected":
		lobby_connected.emit(parsed_message.data.peer_id, parsed_message.data.lobby_info)
	elif parsed_message.type == "lobby_disconnected":
		lobby_disconnected.emit(parsed_message.data.peer_id)


func _on_connected_ok():
	_logger.info("✅ Client connected to server", "_on_connected_ok")
	_logger.info("is_lobby: "+str(is_lobby), "_on_connected_ok")
	if is_lobby:
		_client.send(JSON.stringify({"type": "register_lobby", "data": lobby_info}))
	else:
		_client.send(JSON.stringify({"type": "register_client", "data": {"game": game}}))


func _on_server_disconnected():
	_logger.info("_on_server_disconnected", "_on_server_disconnected")
	server_disconnected.emit()
	if is_lobby:
		get_tree().quit()


func _process(delta):
	if _client:
		_client._process(delta)
