extends Resource
class_name LobbyInfo

@export var port: int
@export var code: String
@export var pId: int
@export var game: String


static func from_json(json_string: String) -> LobbyInfo:
	var data = JSON.parse_string(json_string)
	return from_dict(data)


static func from_dict(data: Dictionary) -> LobbyInfo:
	var info = LobbyInfo.new()
	info.port = data.get("port", 0)
	info.code = data.get("code", "")
	info.pId = data.get("pId", 0)
	info.game = data.get("game", "")
	return info


func to_dict() -> Dictionary:
	return {
		"port": port,
		"code": code,
		"pId": pId,
		"game": game
	}


func to_json() -> String:
	return JSON.stringify(to_dict())
