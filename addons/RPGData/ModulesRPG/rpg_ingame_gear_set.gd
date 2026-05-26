@tool
class_name IngameGearSet
extends Resource

func get_class(): return "IngameGearSet"


## Resource [RPGLPCEquipmentData] that specifies the configuration files for the parts used by this item
@export var equipment_parts: RPGLPCEquipmentData = RPGLPCEquipmentData.new()
## Image used to define the preview for this part
@export var set_preview: String = ""
## Unique ID generated for this item
@export var uniq_id: int = -1
## Real database ID
@export var id: int = 0
## Number of items in possession of this type
@export var quantity: int = 0
## Indicates the type of equipment (0 = IngameCostume, 1 = IngameGearSet)
@export var type: int
## Flag indicating that the item has just been acquired
@export var newly_added: bool = false
## Date of most recent acquisition
@export var last_added_date: int = 0


func _init() -> void:
	uniq_id = RPGSYSTEM.generate_16_digit_id()


func get_real_data() -> RPGCostume:
	return RPGSYSTEM.get_data("costumes", id)


func clear() -> void:
	equipment_parts.clear()
	set_preview = ""


static func create_from_parts(_equipment_parts: RPGLPCEquipmentData) -> IngameGearSet:
	var ingame_set = IngameGearSet.new()
	ingame_set.equipment_parts = _equipment_parts.duplicate_deep(DEEP_DUPLICATE_ALL)
	
	return ingame_set


func _to_string() -> String:
	return "<IngameGearSet: %s>" % get_instance_id()
