extends MultiplayerSpawner
class_name PlayerSpawner

@export_file() var player_scene_path: String
var player_scene: PackedScene
@export var spawn_root: NodePath


var avatars: Dictionary = {}
var _slots: Array[LobbySlot] = []

func _ready():
	multiplayer.peer_disconnected.connect(_handle_leave)
	multiplayer.server_disconnected.connect(_handle_stop)
	
	spawn_path = spawn_root
	add_spawnable_scene(player_scene_path)
	player_scene = load(player_scene_path)

func _handle_leave(id: int):
	if not avatars.has(id):
		return
	
	var avatar = avatars[id] as Node
	avatar.queue_free()
	avatars.erase(id)

func _clear_avatars():
	for avatar in avatars.values():
		avatar.queue_free()
	avatars.clear()

func _handle_stop():
	_clear_avatars()

func _spawn(id: int):
	var avatar = player_scene.instantiate() as Node
	avatars[id] = avatar
	avatar.name += " #%d" % id
	var root = get_node(spawn_root)
	
	
	# Avatar is always owned by server
	avatar.set_multiplayer_authority(1)

	root.add_child(avatar)
	print("Spawned avatar %s at %s" % [avatar.name, multiplayer.get_unique_id()])

func spawn_players(slots):
	if not multiplayer.is_server():
		return
	_slots = slots
	_clear_avatars()
	var filled_slots = slots.filter(func(slot):
		return slot.is_ready
	)
	for slot in filled_slots:
		_spawn(slot.peer_id)
