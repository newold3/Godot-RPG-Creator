@tool
class_name RPGGearUpgrade
extends  Resource


func get_class(): return "RPGGearUpgrade"


@export var max_levels: int = 1
@export var auto_level: bool = false
@export var levels: Array[RPGGearUpgradeLevel] = []


func clear() -> void:
	max_levels = 1
	auto_level = false
	levels.clear()


func clone(value: bool = true) -> RPGGearUpgrade:
	var new_weapon_upgrade = duplicate(value)
	for i in new_weapon_upgrade.levels.size():
		new_weapon_upgrade.levels[i] = new_weapon_upgrade.levels[i].clone(value)
		
	return(new_weapon_upgrade)
