@tool
class_name RPGMapPosition
extends  Resource

func get_class(): return "RPGMapPosition"

## Indicates a position on a specific map

## Destination map id
@export var map_id: int = -1
## Current position on the map (in tiles)
@export var position: Vector2i


func _init(_map_id : int = -1, _position: Vector2i = Vector2i.ZERO) -> void:
	map_id = _map_id
	position = _position


func clear():
	map_id = -1
	position = Vector2i.ZERO


func clone(value: bool) -> RPGMapPosition:
	return duplicate(value)


func _to_string() -> String:
	return "<RPGMapPosition: map_id: %s, position: %s>" % [map_id, position]
