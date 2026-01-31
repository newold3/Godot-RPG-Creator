@tool
class_name IngameGearSet
extends Resource

func get_class(): return "IngameGearSet"


@export var equipment_parts: RPGLPCEquipmentData = RPGLPCEquipmentData.new()
@export var set_peview: String = ""


func clear() -> void:
	equipment_parts.clear()
	set_peview = ""


static func create_from_parts(_equipment_parts: RPGLPCEquipmentData) -> IngameGearSet:
	var ingame_set = IngameGearSet.new()
	ingame_set.equipment_parts = _equipment_parts.duplicate_deep(DEEP_DUPLICATE_ALL)
	
	return ingame_set


func _to_string() -> String:
	return "<IngameGearSet: %s>" % get_instance_id()
