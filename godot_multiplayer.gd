@tool
extends EditorPlugin

const ROOT := "res://addons/godot-multiplayer"
const TYPES: Array[Dictionary] = [
	{
		"name": "LobbyClient",
		"base": "Node",
		"script": ROOT + "/lobby/lobby_client.gd",
		"icon": ROOT + "/icon.svg"
	},
	{
		"name": "LobbyServer",
		"base": "Node",
		"script": ROOT + "/lobby/lobby_server.gd",
		"icon": ROOT + "/icon.svg"
	},
	{
		"name": "GameInstance",
		"base": "Node",
		"script": ROOT + "/game_instance/game_instance.gd",
		"icon": ROOT + "/icon.svg"
	}
]


func _enter_tree():
	# Initialization of the plugin goes here.
	for type in TYPES:
		add_custom_type(type.name, type.base, load(type.script), load(type.icon))


func _exit_tree():
	# Clean-up of the plugin goes here.
	for type in TYPES:
		remove_custom_type(type.name)
