@tool
class_name TroopSpawnData
extends Resource


@export var troop_id: int = 0
@export var occasion: float = 25


func clone(value: bool = true) -> TroopSpawnData:
	return duplicate(value)


func _to_string() -> String:
	return "ID: %s, occasion: %s" % [troop_id, occasion]
