@tool
class_name RPGTroopMember
extends  Resource


func get_class(): return "RPGTroopMember"

## Member type (0 = actor, 1 = enemy)
@export var type: int = 0
## Actor or Enemy ID
@export var id: int = 0
## Member look direction (1 = left, 2 = right, 4 = up, 8 = down)
@export var direction: int = 0
## Member position (normalized)
@export var position: Vector2 = Vector2.ZERO
## Member is hide
@export var hide: bool = false


func _init(p_type: int = 1, p_id: int = 0, p_direction: int = 1, p_position: Vector2 = Vector2.ZERO, p_hide: bool = false) -> void:
	type = p_type
	id = p_id
	direction = p_direction
	position = p_position
	hide = p_hide


func clone(value: bool = true) -> RPGTroopMember:
	return(duplicate(value))
