@tool
class_name RPGEquipRestrictions
extends Resource

func get_class():
	return "RPGEquipRestrictions"


## Restricts its use to characters whose level is greater than or equal to the specified level.
@export var level_restriction: int = 0
## Restricts its use to characters whose class matches the specified class (or 0 to allow any class). Use class uid.
@export var class_restriction: int = 0
## Restricts its use to characters whose gender matches the specified gender (or 0 to allow any gender).
@export var gender_restriction: int = 0


func clear() -> void:
	level_restriction = 0
	class_restriction = 0
	gender_restriction = 0


func clone(value: bool = true) -> RPGEquipRestrictions:
	return duplicate(value)
