extends Node
class_name LobbyManager

signal on_slots_update(slots: Array[LobbySlot])
signal on_game_start_requested(slots: Array[LobbySlot])

@export var player_count := 4
@export var scene :Node
var _slots : Array[LobbySlot]
var _logger:CustomLogger

var _are_all_taken_slots_readied: bool:
	get:
		return _slots.all(func(slot):
			if slot.peer_id == -1:
				return true
			return slot.is_ready
		)

func _ready():
	_logger = CustomLogger.new("GameInstance")
	
	if (multiplayer.is_server()):
		_initialize_slots()
	
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

### SERVER SIDE
func _on_player_connected(peer_id:int):
	if not multiplayer.is_server():
		return
	var free_slot = _get_free_slot()
	
	if not free_slot:
		_logger.info("Kick peer " + str(peer_id) + " because there are too many peers on the server", "_on_peer_connected")
		multiplayer.multiplayer_peer.disconnect_peer(peer_id, true)
		return
	
	free_slot.peer_id = peer_id
	
	_synchronize_slots.rpc(_get_slots_as_json())

func _on_player_disconnected(peer_id:int):
	_free_slot(peer_id)
	
	_synchronize_slots.rpc(_get_slots_as_json())
	
### CLIENT SIDE

func _on_connected_ok():
	pass
	
func _on_connected_fail():
	pass
	
func _on_server_disconnected():
	pass

### METHODS

func _get_slots_as_json() -> String:
	var data = []
	for slot in _slots:
		data.append(slot.to_dictionary())
	return JSON.stringify(data)

func _get_slots_from_json(json: String) -> Array[LobbySlot]:
	var data : Array[LobbySlot]= []
	var slots = JSON.parse_string(json)
	for slot in slots:
		data.append(LobbySlot.from_dictionary(slot))
	return data

func _get_free_slot() -> LobbySlot:
	var index := _slots.find_custom(func(slot: LobbySlot): return slot.peer_id == -1)
	if index == -1:
		return null
	return _slots[index]

func _get_peer_slot(peer_id:int) -> LobbySlot:
	var index := _slots.find_custom(func(slot: LobbySlot): return slot.peer_id == peer_id)
	if index == -1:
		return null
	return _slots[index]

func _free_slot(peer_id:int):
	var index := _slots.find_custom(func(slot: LobbySlot): return slot.peer_id == peer_id)
	if index == -1:
		return
	var slot :LobbySlot= _slots[index]
	slot.reset()

func _are_all_slots_ready() -> bool:
	return _slots.all(func(slot: LobbySlot): return slot.is_ready)

func start():
	_start.rpc_id(1)

@rpc("any_peer", "reliable")
func _start():
	if not multiplayer.is_server():
		return
	if _are_all_taken_slots_readied:
		on_game_start_requested.emit(_slots)

func _initialize_slots():
	for i in range(player_count):
		var lobbySlot = LobbySlot.new()
		_slots.append(lobbySlot)
		
@rpc("any_peer", "reliable")
func _synchronize_slots(json):
	_logger.debug("_synchronize_slots")
	_slots.clear()
	_slots.assign(_get_slots_from_json(json))
	on_slots_update.emit(_slots)

func ready_peer(peer_id):
	_ready_peer.rpc_id(1, peer_id)

@rpc("any_peer", "reliable")
func _ready_peer(peer_id):
	if not multiplayer.is_server():
		return
	_logger.debug("_ready_peer " + str(peer_id))
	var peer_slot := _get_peer_slot(peer_id)
	
	if not peer_slot:
		return
		
	peer_slot.is_ready = true
	_synchronize_slots.rpc(_get_slots_as_json())
	
	if _are_all_slots_ready():
		_start()
