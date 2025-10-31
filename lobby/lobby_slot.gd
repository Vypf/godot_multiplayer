extends Resource
class_name LobbySlot

const NO_PEER = -1

var peer_id:int = NO_PEER
var is_ready:= false

func reset():
	peer_id = NO_PEER
	is_ready = false

func to_dictionary() -> Dictionary:
	return {
		"peer_id": peer_id,
		"is_ready": is_ready
	}
	
static func from_dictionary(dict: Dictionary) -> LobbySlot:
	var lobby_slot = LobbySlot.new()
	lobby_slot.peer_id = dict.peer_id
	lobby_slot.is_ready = dict.is_ready
	return lobby_slot
