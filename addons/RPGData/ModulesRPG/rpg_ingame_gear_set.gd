@tool
class_name IngameGearSet
extends Resource

func get_class(): return "IngameGearSet"


@export var equipment_parts: RPGLPCEquipmentData = RPGLPCEquipmentData.new()
@export var set_preview: String = ""

@export var uniq_id: int = -1 # Unique ID generated for this item
@export var id: int = 0 # real database id
@export var quantity: int = 0 # Number of items in possession of this type
@export var type: int # Indicates the type of equipment (0 = IngameCostume, 1 = IngameGearSet)
@export var newly_added: bool = false
@export var last_added_date: int = 0 # Date of most recent acquisition


func clear() -> void:
	equipment_parts.clear()
	set_preview = ""


static func create_from_parts(_equipment_parts: RPGLPCEquipmentData) -> IngameGearSet:
	var ingame_set = IngameGearSet.new()
	ingame_set.equipment_parts = _equipment_parts.duplicate_deep(DEEP_DUPLICATE_ALL)
	
	return ingame_set


func _to_string() -> String:
	return "<IngameGearSet: %s>" % get_instance_id()
