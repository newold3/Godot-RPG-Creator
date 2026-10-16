@tool
class_name RPGGearUpgrade
extends  Resource


func get_class(): return "RPGGearUpgrade"


@export var max_levels: int = 1
@export var auto_level: bool = false
@export var levels: Array[RPGGearUpgradeLevel] = []

## Custom data dictionary for future expansion and dynamic properties.
@export var custom_data: Dictionary = {}


func clear() -> void:
	max_levels = 1
	auto_level = false
	levels.clear()
	if custom_data != null:
		custom_data.clear()
	else:
		custom_data = {}


func clone(value: bool = true) -> RPGGearUpgrade:
	var new_weapon_upgrade = duplicate(value)
	for i in new_weapon_upgrade.levels.size():
		if not new_weapon_upgrade.levels[i]:
			new_weapon_upgrade.levels[i] = RPGGearUpgradeLevel.new()
		new_weapon_upgrade.levels[i] = new_weapon_upgrade.levels[i].clone(value)
		
	new_weapon_upgrade.custom_data = custom_data.duplicate(true) if custom_data != null else {}
	return(new_weapon_upgrade)
