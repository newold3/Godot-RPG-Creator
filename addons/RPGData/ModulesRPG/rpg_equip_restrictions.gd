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

## Custom data dictionary for future expansion and dynamic properties.
@export var custom_data: Dictionary = {}


func clear() -> void:
	level_restriction = 0
	class_restriction = 0
	gender_restriction = 0
	if custom_data != null:
		custom_data.clear()
	else:
		custom_data = {}


func clone(value: bool = true) -> RPGEquipRestrictions:
	var copy = duplicate(value)
	copy.custom_data = custom_data.duplicate(true) if custom_data != null else {}
	return copy
