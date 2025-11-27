extends Control
class_name OnlineMultiplayerScreen

@export var lobby_client: LobbyClient

@onready var lobby_panel: LobbyPanel = %LobbyPanel

signal on_lobby_joined(lobby_info: LobbyInfo)

var _requested_lobby_code: String = ""

func _ready():
	lobby_client.lobby_created.connect(_on_lobby_created)
	lobby_client.lobbies_updated.connect(_on_lobbies_updated)
	lobby_panel.on_host_click.connect(_on_host_click)
	lobby_panel.on_join_click.connect(_on_join_click)

func _on_lobby_created(lobby_info: LobbyInfo):
	# Store the code and wait for lobbies_updated to confirm the server is ready
	_requested_lobby_code = lobby_info.code

func _on_lobbies_updated():
	if _requested_lobby_code.is_empty():
		return
	# Check if our created lobby is now registered and ready
	var peer_id: String = _find_key(lobby_client.lobbies, func(key, value):
		return value.code == _requested_lobby_code
	, "")
	if not peer_id.is_empty():
		var lobby_info: LobbyInfo = lobby_client.lobbies[peer_id]
		_requested_lobby_code = ""
		on_lobby_joined.emit(lobby_info)

func _on_host_click():
	lobby_client.create()

func _on_join_click(code: String):
	var peer_id: String = _find_key(lobby_client.lobbies, func(key, value):
		return value.code == code
	, "")
	if not peer_id.is_empty():
		var lobby_info: LobbyInfo = lobby_client.lobbies[peer_id]
		on_lobby_joined.emit(lobby_info)

## Returns the first key in the dictionary for which the callable returns true.
## - dict: Dictionary to iterate over
## - predicate: a Callable that receives (key, value)
## - default: value returned if no key matches
func _find_key(dict: Dictionary, predicate: Callable, default: Variant = null):
	for key in dict.keys():
		var value = dict[key]
		if predicate.call(key, value):
			return key
	return default
