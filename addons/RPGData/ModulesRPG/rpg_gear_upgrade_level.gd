@tool
class_name RPGGearUpgradeLevel
extends  Resource


func get_class(): return "RPGGearUpgradeLevel"


@export var required_materials: Array[RPGGearUpgradeComponent] = []
@export var required_gold: int = 0
@export var required_experience: int = 1 # Weapon usage counter / Armors battle count
@export var parameters_multiplier: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
@export var user_parameters: PackedFloat32Array = []
@export var price_increment: float = 0.0

## Custom data dictionary for future expansion and dynamic properties.
@export var custom_data: Dictionary = {}


func clone(value: bool = true) -> RPGGearUpgradeLevel:
	var new_weapon_upgrade_level = duplicate(value)
	for i in new_weapon_upgrade_level.required_materials.size():
		new_weapon_upgrade_level.required_materials[i] = new_weapon_upgrade_level.required_materials[i].clone(value)
	
	new_weapon_upgrade_level.custom_data = custom_data.duplicate(true) if custom_data != null else {}
	return new_weapon_upgrade_level


func _to_string() -> String:
	return "<RPGGearUpgradeLevel params=%s>" % parameters_multiplier
