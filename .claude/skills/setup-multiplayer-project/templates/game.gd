extends Node2D
class_name Game

@onready var game_instance: GameInstance = %GameInstance
@onready var lobby_client: LobbyClient = %LobbyClient
@onready var online_multiplayer_screen: OnlineMultiplayerScreen = %OnlineMultiplayerScreen
@onready var lobby_manager: LobbyManager = %LobbyManager
@onready var waiting_room: WaitingRoom = %WaitingRoom
@onready var player_spawner: PlayerSpawner = %PlayerSpawner
@onready var lobby_server: LobbyServer = %LobbyServer
@onready var level = %Level

const TYPES := {
	"PLAYER": "PLAYER",
	"SERVER": "room",
	"LOBBY": "lobby"
}

var type: String:
	get:
		return Config.arguments.get("server_type", TYPES.PLAYER)

const LOBBY_PORT = 17018

## Server URL - in web exports, uses the production URL from ProjectSettings
## Bug workaround: feature tag overrides don't work at runtime (godotengine/godot#101207)
var server_url: String:
	get:
		if OS.has_feature("web"):
			return ProjectSettings.get_setting("application/config/server_url_production", "")
		return ProjectSettings.get_setting("application/config/server_url", "")

## Returns true if server_url is configured (via feature tag in export)
var is_production: bool:
	get:
		return not server_url.is_empty()


func get_game_instance_url(lobby_info: LobbyInfo) -> String:
	if is_production:
		return "wss://" + server_url + "/" + lobby_info.code
	return "ws://localhost:" + str(lobby_info.port)


func get_lobby_manager_url() -> String:
	if Config.arguments.has("lobby_url"):
		return Config.arguments["lobby_url"]
	if is_production:
		return "wss://" + server_url + "/lobby"
	return "ws://localhost:" + str(LOBBY_PORT)


func _ready():
	if type == TYPES.PLAYER:
		_setup_player()
	elif type == TYPES.SERVER:
		_setup_server()
	elif type == TYPES.LOBBY:
		_setup_lobby()


func _setup_player():
	_set_window_title(TYPES.PLAYER)

	waiting_room.on_ready.connect(func(peer_id):
		lobby_manager.ready_peer(peer_id)
	)
	waiting_room.on_start_clicked.connect(func():
		lobby_manager.start()
	)
	lobby_manager.on_slots_update.connect(func(slots):
		waiting_room.peer_id = multiplayer.get_unique_id()
		waiting_room.slots = slots
	)

	game_instance.code_received.connect(func(_code):
		hide_screen(online_multiplayer_screen)
		waiting_room.show()
	)

	online_multiplayer_screen.on_lobby_joined.connect(func(lobby_info: LobbyInfo):
		game_instance.create_client(get_game_instance_url(lobby_info))
	)

	lobby_client.join(get_lobby_manager_url())


func _setup_server():
	_set_window_title(TYPES.SERVER)
	hide_screen(online_multiplayer_screen)

	lobby_manager.on_game_start_requested.connect(func(slots):
		player_spawner.spawn_players(slots)
		# Ajouter ici la logique de démarrage du niveau si nécessaire
	)

	var port = Config.arguments.get("port", null)
	var code = Config.arguments.get("code", null)

	if port == null or code == null:
		print("Can't start game instance because port or code is missing.")
		return

	game_instance.create_server(port, code)
	var info = LobbyInfo.new()
	info.port = int(port)
	info.code = code
	info.pId = OS.get_process_id()
	lobby_client.lobby_info = info
	lobby_client.join(get_lobby_manager_url())


func _setup_lobby():
	_set_window_title(TYPES.LOBBY)
	hide_screen(online_multiplayer_screen)

	var instance_manager = LocalInstanceManager.new(
		Config.arguments.get("paths", {}),
		Config.arguments.get("executable_paths", {}),
		Config.arguments.get("log_folder", ""),
		Config.arguments.get("environment", "development"),
		Config.arguments.get("lobby_url", "")
	)
	lobby_server._instance_manager = instance_manager
	lobby_server.start(Config.arguments.get("port", LOBBY_PORT))


func hide_screen(screen: Control):
	screen.hide()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.set_process(false)
	screen.set_process_input(false)


func _set_window_title(title: String):
	var window = get_window()
	if window:
		window.title = title
