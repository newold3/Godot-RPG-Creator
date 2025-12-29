@tool
class_name SelfSwitches
extends Resource


func get_class(): return "SelfSwitches"


@export var data: Dictionary = {}
@export var keys: Array = [
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
	"N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"
]


func add_self_switch(map_id: int, event_id: int, switch_id: String, switch_value: bool) -> void:
	var real_id = [map_id, event_id, switch_id]
	data[real_id] = switch_value


func get_self_switch(map_id: int, event_id: int, switch_id: String) -> bool:
	var real_id = [map_id, event_id, switch_id]
	if data.has(real_id):
		return data[real_id]
	else:
		return false


func get_self_switch_name(switch_id: int) -> String:
	if keys.size() > switch_id:
		return keys[switch_id]
	else:
		return ""


func add_self_switch_key(key: String) -> void:
	keys.append(key)


func remove_self_switch_key(key: String) -> void:
	if keys.has(key):
		keys.erase(key)


func remove_self_switch(map_id: int, event_id: int, switch_id: String) -> void:
	var real_id = [map_id, event_id, switch_id]
	if data.has(real_id):
		data.erase(real_id)


func get_switch_names() -> Array:
	return keys


func size() -> int:
	return data.size()
