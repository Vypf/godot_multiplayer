extends Node
class_name GameInstance

signal code_received(code: String)
signal player_joined(peer_id)
signal player_left(peer_id)
signal server_disconnected
signal server_connected

const SERVER_ID = 1

var max_players := 4
var players_count:int:
	get:
		return multiplayer.get_peers().size() - 1
var code
var is_online: bool = false
var is_server: bool:
	get:
		return (
			not multiplayer.multiplayer_peer is OfflineMultiplayerPeer and multiplayer.is_server()
		)
var peer := WebSocketMultiplayerPeer.new()

var _logger: CustomLogger

func _ready():
	_logger = CustomLogger.new("GameInstance")

func create_server(port, p_code):
	code = p_code
	if is_online:
		return
	_logger.info("Attempting to create server on port " + str(port), "create_server")
	var error := peer.create_server(int(port))
	if error != OK:
		_logger.error("Failed to create server: " + str(error), "create_server")
		return error
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(
		func(peer_id):
			_logger.info("Peer " + str(peer_id) + " disconnected from the server", "create_server")
			player_left.emit(peer_id)
	)
	multiplayer.multiplayer_peer = peer

	is_online = true


func _on_peer_connected(peer_id: int) -> void:
	if peer_id == SERVER_ID:
		return
	if players_count >= max_players:
		_logger.info("Kick peer " + str(peer_id) + " because there are too many peers on the server", "_on_peer_connected")
		multiplayer.multiplayer_peer.disconnect_peer(peer_id, true)
		return
	_logger.info("Peer " + str(peer_id) + " connected to the server", "_on_peer_connected")
	_register_room_code.rpc_id(peer_id, code)
	player_joined.emit(peer_id)


@rpc("any_peer", "reliable")
func _register_room_code(p_code):
	code = p_code
	code_received.emit(code)


func create_client(address = ""):
	if is_online:
		return
	multiplayer.server_disconnected.connect(
		func():
			_logger.info("SERVER DISCONNECTED", "create_client")
			server_disconnected.emit()
			is_online = false
	)
	multiplayer.connection_failed.connect(
		func():
			_logger.info("SERVER DISCONNECTED", "create_client")
			server_disconnected.emit()
			is_online = false
	)
	multiplayer.connected_to_server.connect(func(): server_connected.emit())
	_logger.info("Attempting to connect to server at address: " + address, "create_client")
	var error = peer.create_client(address)
	if error:
		_logger.error("Failed to create client connection: " + str(error), "create_client")
		return error
	multiplayer.multiplayer_peer = peer

	_logger.info("Connected to server at address: " + address, "create_client")
	is_online = true


func stop():
	if peer.get_connection_status() == WebSocketMultiplayerPeer.CONNECTION_CONNECTED:
		peer.close()

	await get_tree().process_frame

	multiplayer.multiplayer_peer = null
	peer = WebSocketMultiplayerPeer.new()
