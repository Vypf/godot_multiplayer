extends Node2D
## Base player class with multiplayer authority setup.
##
## The Input node authority is set to the owning player (peer_id = node name).
## The Player node itself remains owned by the server (default).

@onready var input: OnlineInput = %Input


func _ready():
	# Input node is owned by the player (peer_id = node name)
	var input_node = find_child("Input")
	if input_node != null:
		input_node.set_multiplayer_authority(int(name))


func _physics_process(delta) -> void:
	if not is_multiplayer_authority():
		return

	# Implement your movement logic here using input properties
	# Example: position += input.direction * speed * delta
	pass
