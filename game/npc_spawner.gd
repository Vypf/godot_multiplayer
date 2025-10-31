extends MultiplayerSpawner

func _ready():
	spawn_function = _spawn_npc
	
func _spawn_npc(data) -> Node:
	var scene_path = data
	if scene_path == "":
		push_warning("spawn_function: scène invalide")
		return null
	var packed = ResourceLoader.load(scene_path)
	if not packed:
		push_warning("spawn_function: impossible de charger %s" % scene_path)
		return null
	var inst = packed.instantiate()
	return inst
